package grpc

import (
	"context"

	queryv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/queryv1"
)

type QueryService interface {
	CreateLoanQuery(ctx context.Context, req *queryv1.CreateLoanQueryRequest) (*queryv1.CreateLoanQueryResponse, error)
	GetLoanQuery(ctx context.Context, req *queryv1.GetLoanQueryRequest) (*queryv1.GetLoanQueryResponse, error)
	ListLoanQueries(ctx context.Context, req *queryv1.ListLoanQueriesRequest) (*queryv1.ListLoanQueriesResponse, error)
	UpdateLoanQueryStatus(ctx context.Context, req *queryv1.UpdateLoanQueryStatusRequest) (*queryv1.UpdateLoanQueryStatusResponse, error)
}

type QueryHandler struct {
	queryv1.UnimplementedQueryServiceServer
	queryService QueryService
}

func NewQueryHandler(queryService QueryService) *QueryHandler {
	return &QueryHandler{queryService: queryService}
}

func (h *QueryHandler) CreateLoanQuery(ctx context.Context, req *queryv1.CreateLoanQueryRequest) (*queryv1.CreateLoanQueryResponse, error) {
	return h.queryService.CreateLoanQuery(ctx, req)
}

func (h *QueryHandler) GetLoanQuery(ctx context.Context, req *queryv1.GetLoanQueryRequest) (*queryv1.GetLoanQueryResponse, error) {
	return h.queryService.GetLoanQuery(ctx, req)
}

func (h *QueryHandler) ListLoanQueries(ctx context.Context, req *queryv1.ListLoanQueriesRequest) (*queryv1.ListLoanQueriesResponse, error) {
	return h.queryService.ListLoanQueries(ctx, req)
}

func (h *QueryHandler) UpdateLoanQueryStatus(ctx context.Context, req *queryv1.UpdateLoanQueryStatusRequest) (*queryv1.UpdateLoanQueryStatusResponse, error) {
	return h.queryService.UpdateLoanQueryStatus(ctx, req)
}
