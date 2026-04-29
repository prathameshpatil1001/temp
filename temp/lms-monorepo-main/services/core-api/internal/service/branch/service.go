package branch

import (
	"context"
	"strconv"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	branchv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/branchv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	branchv1.BranchServiceServer
}

type service struct {
	branchv1.UnimplementedBranchServiceServer
	queries generated.Querier
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries}
}

func (s *service) ListBranches(ctx context.Context, req *branchv1.ListBranchesRequest) (*branchv1.ListBranchesResponse, error) {
	if _, ok := interceptors.UserIDFromContext(ctx); !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	limit := req.GetLimit()
	if limit <= 0 || limit > 500 {
		limit = 100
	}

	offset := req.GetOffset()
	if offset < 0 {
		offset = 0
	}

	rows, err := s.queries.ListBankBranches(ctx, generated.ListBankBranchesParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list branches")
	}

	branches := make([]*branchv1.BankBranch, 0, len(rows))
	for _, row := range rows {
		createdAt := ""
		if row.CreatedAt.Valid {
			createdAt = row.CreatedAt.Time.UTC().Format(time.RFC3339)
		}

		branches = append(branches, &branchv1.BankBranch{
			Id:            row.ID.String(),
			Name:          row.Name,
			Region:        row.Region,
			City:          row.City,
			DstCommission: numericToString(row.DstCommission),
			CreatedAt:     createdAt,
		})
	}

	return &branchv1.ListBranchesResponse{Branches: branches}, nil
}

func numericToString(v pgtype.Numeric) string {
	if !v.Valid {
		return "0"
	}
	raw, err := v.Value()
	if err == nil {
		switch t := raw.(type) {
		case string:
			return t
		case []byte:
			return string(t)
		}
	}
	f, err := v.Float64Value()
	if err != nil || !f.Valid {
		return "0"
	}
	return strconv.FormatFloat(f.Float64, 'f', -1, 64)
}
