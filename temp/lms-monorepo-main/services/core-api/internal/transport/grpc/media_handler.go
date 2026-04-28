package grpc

import (
	"context"

	mediav1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/mediav1"
)

type MediaService interface {
	InitiateMediaUpload(ctx context.Context, req *mediav1.InitiateMediaUploadRequest) (*mediav1.InitiateMediaUploadResponse, error)
	CompleteMediaUpload(ctx context.Context, req *mediav1.CompleteMediaUploadRequest) (*mediav1.CompleteMediaUploadResponse, error)
	ListMedia(ctx context.Context, req *mediav1.ListMediaRequest) (*mediav1.ListMediaResponse, error)
}

type MediaHandler struct {
	mediav1.UnimplementedMediaServiceServer
	mediaService MediaService
}

func NewMediaHandler(mediaService MediaService) *MediaHandler {
	return &MediaHandler{mediaService: mediaService}
}

func (h *MediaHandler) InitiateMediaUpload(ctx context.Context, req *mediav1.InitiateMediaUploadRequest) (*mediav1.InitiateMediaUploadResponse, error) {
	return h.mediaService.InitiateMediaUpload(ctx, req)
}

func (h *MediaHandler) CompleteMediaUpload(ctx context.Context, req *mediav1.CompleteMediaUploadRequest) (*mediav1.CompleteMediaUploadResponse, error) {
	return h.mediaService.CompleteMediaUpload(ctx, req)
}

func (h *MediaHandler) ListMedia(ctx context.Context, req *mediav1.ListMediaRequest) (*mediav1.ListMediaResponse, error) {
	return h.mediaService.ListMedia(ctx, req)
}
