package media

import (
	"context"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/r2"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	mediav1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/mediav1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const storageProviderR2 = "r2"

var allowedContentTypes = map[string]struct{}{
	"image/jpeg":      {},
	"image/png":       {},
	"application/pdf": {},
}

type Service interface {
	InitiateMediaUpload(ctx context.Context, req *mediav1.InitiateMediaUploadRequest) (*mediav1.InitiateMediaUploadResponse, error)
	CompleteMediaUpload(ctx context.Context, req *mediav1.CompleteMediaUploadRequest) (*mediav1.CompleteMediaUploadResponse, error)
	ListMedia(ctx context.Context, req *mediav1.ListMediaRequest) (*mediav1.ListMediaResponse, error)
}

type service struct {
	queries          *generated.Queries
	r2Client         *r2.Client
	uploadURLTTL     time.Duration
	mediaMaxFileSize int64
}

func NewService(queries *generated.Queries, r2Client *r2.Client, uploadURLTTL time.Duration, mediaMaxFileSize int64) Service {
	return &service{queries: queries, r2Client: r2Client, uploadURLTTL: uploadURLTTL, mediaMaxFileSize: mediaMaxFileSize}
}

func (s *service) InitiateMediaUpload(ctx context.Context, req *mediav1.InitiateMediaUploadRequest) (*mediav1.InitiateMediaUploadResponse, error) {
	userID, err := requireUser(ctx)
	if err != nil {
		return nil, err
	}

	fileName := strings.TrimSpace(req.GetFileName())
	contentType := strings.TrimSpace(strings.ToLower(req.GetContentType()))
	sizeBytes := req.GetSizeBytes()
	if fileName == "" || contentType == "" || sizeBytes <= 0 {
		return nil, status.Error(codes.InvalidArgument, "file_name, content_type and size_bytes are required")
	}
	if sizeBytes > s.mediaMaxFileSize {
		return nil, status.Errorf(codes.InvalidArgument, "file size exceeds maximum limit of %d bytes", s.mediaMaxFileSize)
	}
	if _, ok := allowedContentTypes[contentType]; !ok {
		return nil, status.Error(codes.InvalidArgument, "unsupported content_type")
	}

	objectKey := buildObjectKey(userID, fileName)
	uploadURL, err := s.r2Client.PresignPutObject(ctx, objectKey, contentType, s.uploadURLTTL)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create upload url")
	}

	expiresAt := time.Now().UTC().Add(s.uploadURLTTL).Format(time.RFC3339)

	return &mediav1.InitiateMediaUploadResponse{
		Success:      true,
		ObjectKey:    objectKey,
		UploadUrl:    uploadURL,
		UploadMethod: "PUT",
		ExpiresAt:    expiresAt,
	}, nil
}

func (s *service) CompleteMediaUpload(ctx context.Context, req *mediav1.CompleteMediaUploadRequest) (*mediav1.CompleteMediaUploadResponse, error) {
	userID, err := requireUser(ctx)
	if err != nil {
		return nil, err
	}

	objectKey := strings.TrimSpace(req.GetObjectKey())
	note := strings.TrimSpace(req.GetNote())
	if objectKey == "" {
		return nil, status.Error(codes.InvalidArgument, "object_key is required")
	}

	etag, err := s.r2Client.HeadObject(ctx, objectKey)
	if err != nil {
		return nil, status.Error(codes.FailedPrecondition, "uploaded object not found")
	}

	fileName := strings.TrimSpace(req.GetFileName())
	if fileName == "" {
		fileName = filepath.Base(objectKey)
	}
	contentType := strings.TrimSpace(strings.ToLower(req.GetContentType()))
	if contentType == "" {
		contentType = inferContentType(fileName)
	}
	sizeBytes := req.GetSizeBytes()
	if sizeBytes <= 0 {
		sizeBytes = 1
	}
	url := s.r2Client.ObjectURL(objectKey)
	now := nowPgTimestamptz()

	created, err := s.queries.CreateMediaFile(ctx, generated.CreateMediaFileParams{
		UserID:           pgtype.UUID{Bytes: userID, Valid: true},
		OriginalFileName: fileName,
		ContentType:      contentType,
		SizeBytes:        sizeBytes,
		StorageProvider:  storageProviderR2,
		BucketName:       s.r2Client.Bucket(),
		ObjectKey:        objectKey,
		Etag:             textOrNull(etag),
		FileUrl:          url,
		Note:             textOrNull(note),
		UploadedAt:       now,
		UpdatedAt:        now,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to store media metadata")
	}

	return &mediav1.CompleteMediaUploadResponse{
		Success:    true,
		MediaId:    created.ID.String(),
		FileUrl:    created.FileUrl,
		UploadedAt: timeToString(created.UploadedAt),
	}, nil
}

func (s *service) ListMedia(ctx context.Context, req *mediav1.ListMediaRequest) (*mediav1.ListMediaResponse, error) {
	userID, err := requireUser(ctx)
	if err != nil {
		return nil, err
	}

	limit := req.GetLimit()
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	offset := req.GetOffset()
	if offset < 0 {
		offset = 0
	}

	rows, err := s.queries.ListMediaFilesByUser(ctx, generated.ListMediaFilesByUserParams{
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list media")
	}

	items := make([]*mediav1.MediaItem, 0, len(rows))
	for _, row := range rows {
		items = append(items, &mediav1.MediaItem{
			MediaId:     row.ID.String(),
			FileName:    row.OriginalFileName,
			ContentType: row.ContentType,
			SizeBytes:   row.SizeBytes,
			FileUrl:     row.FileUrl,
			Note:        row.Note.String,
			UploadedAt:  timeToString(row.UploadedAt),
		})
	}

	return &mediav1.ListMediaResponse{Items: items}, nil
}

func requireUser(ctx context.Context) (uuid.UUID, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return uuid.UUID{}, status.Error(codes.Unauthenticated, "missing user context")
	}
	return userID, nil
}

func buildObjectKey(userID uuid.UUID, fileName string) string {
	ext := strings.ToLower(filepath.Ext(fileName))
	base := strings.TrimSuffix(fileName, filepath.Ext(fileName))
	base = sanitize(base)
	return fmt.Sprintf("media/%s/%d_%s%s", userID.String(), time.Now().UTC().UnixNano(), base, ext)
}

func sanitize(v string) string {
	v = strings.TrimSpace(strings.ToLower(v))
	v = strings.ReplaceAll(v, " ", "-")
	if v == "" {
		return "file"
	}
	return v
}

func inferContentType(fileName string) string {
	ext := strings.ToLower(filepath.Ext(fileName))
	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".pdf":
		return "application/pdf"
	default:
		return "application/octet-stream"
	}
}

func textOrNull(v string) pgtype.Text {
	v = strings.TrimSpace(v)
	if v == "" {
		return pgtype.Text{}
	}
	return pgtype.Text{String: v, Valid: true}
}

func nowPgTimestamptz() pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: time.Now().UTC(), Valid: true}
}

func timeToString(t pgtype.Timestamptz) string {
	if !t.Valid {
		return ""
	}
	return t.Time.UTC().Format(time.RFC3339)
}
