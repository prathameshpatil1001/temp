package grpc

import (
	"context"

	branchv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/branchv1"
)

type BranchService interface {
	ListBranches(ctx context.Context, req *branchv1.ListBranchesRequest) (*branchv1.ListBranchesResponse, error)
}

type BranchHandler struct {
	branchv1.UnimplementedBranchServiceServer
	branchService BranchService
}

func NewBranchHandler(branchService BranchService) *BranchHandler {
	return &BranchHandler{branchService: branchService}
}

func (h *BranchHandler) ListBranches(ctx context.Context, req *branchv1.ListBranchesRequest) (*branchv1.ListBranchesResponse, error) {
	return h.branchService.ListBranches(ctx, req)
}
