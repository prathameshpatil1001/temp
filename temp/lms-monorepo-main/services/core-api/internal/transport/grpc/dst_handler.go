package grpc

import (
	"context"

	dstv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/dstv1"
)

type DstService interface {
	GetDstAccount(ctx context.Context, req *dstv1.GetDstAccountRequest) (*dstv1.GetDstAccountResponse, error)
	ListDstAccounts(ctx context.Context, req *dstv1.ListDstAccountsRequest) (*dstv1.ListDstAccountsResponse, error)
}

type DstHandler struct {
	dstv1.UnimplementedDstServiceServer
	dstService DstService
}

func NewDstHandler(dstService DstService) *DstHandler {
	return &DstHandler{dstService: dstService}
}

func (h *DstHandler) GetDstAccount(ctx context.Context, req *dstv1.GetDstAccountRequest) (*dstv1.GetDstAccountResponse, error) {
	return h.dstService.GetDstAccount(ctx, req)
}

func (h *DstHandler) ListDstAccounts(ctx context.Context, req *dstv1.ListDstAccountsRequest) (*dstv1.ListDstAccountsResponse, error) {
	return h.dstService.ListDstAccounts(ctx, req)
}
