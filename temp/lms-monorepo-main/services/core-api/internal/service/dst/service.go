package dst

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	dstv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/dstv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	GetDstAccount(ctx context.Context, req *dstv1.GetDstAccountRequest) (*dstv1.GetDstAccountResponse, error)
	ListDstAccounts(ctx context.Context, req *dstv1.ListDstAccountsRequest) (*dstv1.ListDstAccountsResponse, error)
}

type service struct {
	queries generated.Querier
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries}
}

func (s *service) GetDstAccount(ctx context.Context, req *dstv1.GetDstAccountRequest) (*dstv1.GetDstAccountResponse, error) {
	callerRole, callerBranchID, err := s.requireAdminOrManagerScope(ctx)
	if err != nil {
		return nil, err
	}

	userIDStr := strings.TrimSpace(req.GetUserId())
	if userIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "user_id must be a valid uuid")
	}

	row, err := s.queries.GetDstAccountByUserID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "dst account not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch dst account")
	}

	if callerRole == "manager" && (!row.BranchID.Valid || row.BranchID.Bytes != callerBranchID) {
		return nil, status.Error(codes.PermissionDenied, "manager can only access dst accounts from their own branch")
	}

	return &dstv1.GetDstAccountResponse{Account: mapDstAccountRow(row)}, nil
}

func (s *service) ListDstAccounts(ctx context.Context, req *dstv1.ListDstAccountsRequest) (*dstv1.ListDstAccountsResponse, error) {
	callerRole, callerBranchID, err := s.requireAdminOrManagerScope(ctx)
	if err != nil {
		return nil, err
	}

	branchID := callerBranchID
	branchIDStr := strings.TrimSpace(req.GetBranchId())
	if branchIDStr != "" {
		parsedBranchID, err := uuid.Parse(branchIDStr)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "branch_id must be a valid uuid")
		}
		branchID = parsedBranchID
	}

	if callerRole == "manager" && branchID != callerBranchID {
		return nil, status.Error(codes.PermissionDenied, "manager can only list dst accounts from their own branch")
	}

	if _, err := s.queries.GetBankBranchByID(ctx, pgtype.UUID{Bytes: branchID, Valid: true}); err != nil {
		return nil, status.Error(codes.NotFound, "branch not found")
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

	rows, err := s.queries.ListDstAccountsByBranchID(ctx, generated.ListDstAccountsByBranchIDParams{
		BranchID: pgtype.UUID{Bytes: branchID, Valid: true},
		Limit:    limit,
		Offset:   offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list dst accounts")
	}

	items := make([]*dstv1.DstAccount, 0, len(rows))
	for _, row := range rows {
		item := row
		items = append(items, mapDstListRow(item))
	}

	return &dstv1.ListDstAccountsResponse{Items: items}, nil
}

func (s *service) requireAdminOrManagerScope(ctx context.Context) (string, uuid.UUID, error) {
	callerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return "", uuid.UUID{}, status.Error(codes.Unauthenticated, "missing user context")
	}

	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	if role != "admin" && role != "manager" {
		return "", uuid.UUID{}, status.Error(codes.PermissionDenied, "only admin or manager can access dst accounts")
	}

	if role == "admin" {
		return role, uuid.UUID{}, nil
	}

	managerProfile, err := s.queries.GetManagerProfileByUserID(ctx, pgtype.UUID{Bytes: callerUserID, Valid: true})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", uuid.UUID{}, status.Error(codes.NotFound, "manager profile not found")
		}
		return "", uuid.UUID{}, status.Error(codes.Internal, "failed to load manager profile")
	}
	if !managerProfile.BranchID.Valid {
		return "", uuid.UUID{}, status.Error(codes.FailedPrecondition, "manager is not assigned to a branch")
	}

	return role, uuid.UUID(managerProfile.BranchID.Bytes), nil
}

func mapDstAccountRow(row generated.GetDstAccountByUserIDRow) *dstv1.DstAccount {
	return &dstv1.DstAccount{
		UserId:                    row.UserID.String(),
		ProfileId:                 row.ProfileID.String(),
		Name:                      row.Name,
		Email:                     row.Email,
		PhoneNumber:               row.Phone,
		IsActive:                  row.IsActive.Bool,
		IsRequiringPasswordChange: row.IsRequiringPasswordChange.Bool,
		BranchId:                  row.BranchID.String(),
		BranchName:                row.BranchName,
		BranchRegion:              row.BranchRegion,
		BranchCity:                row.BranchCity,
		CreatedAt:                 timeToString(row.CreatedAt),
	}
}

func mapDstListRow(row generated.ListDstAccountsByBranchIDRow) *dstv1.DstAccount {
	return &dstv1.DstAccount{
		UserId:                    row.UserID.String(),
		ProfileId:                 row.ProfileID.String(),
		Name:                      row.Name,
		Email:                     row.Email,
		PhoneNumber:               row.Phone,
		IsActive:                  row.IsActive.Bool,
		IsRequiringPasswordChange: row.IsRequiringPasswordChange.Bool,
		BranchId:                  row.BranchID.String(),
		BranchName:                row.BranchName,
		BranchRegion:              row.BranchRegion,
		BranchCity:                row.BranchCity,
		CreatedAt:                 timeToString(row.CreatedAt),
	}
}

func timeToString(t pgtype.Timestamptz) string {
	if !t.Valid {
		return ""
	}
	return t.Time.UTC().Format(time.RFC3339)
}
