package grpc

import (
	"context"

	adminv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/adminv1"
)

type AdminService interface {
	CreateAdminAccount(ctx context.Context, req *adminv1.CreateAdminAccountRequest) (*adminv1.CreateAdminAccountResponse, error)
	CreateEmployeeAccount(ctx context.Context, req *adminv1.CreateEmployeeAccountRequest) (*adminv1.CreateEmployeeAccountResponse, error)
	ListEmployeeAccounts(ctx context.Context, req *adminv1.ListEmployeeAccountsRequest) (*adminv1.ListEmployeeAccountsResponse, error)
	ListBranchOfficers(ctx context.Context, req *adminv1.ListBranchOfficersRequest) (*adminv1.ListBranchOfficersResponse, error)
	CreateDstAccount(ctx context.Context, req *adminv1.CreateDstAccountRequest) (*adminv1.CreateDstAccountResponse, error)
	UpdateDstAccount(ctx context.Context, req *adminv1.UpdateDstAccountRequest) (*adminv1.UpdateDstAccountResponse, error)
	CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error)
	UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error)
	DeleteBankBranch(ctx context.Context, req *adminv1.DeleteBankBranchRequest) (*adminv1.DeleteBankBranchResponse, error)
	UpdateBranchDstCommission(ctx context.Context, req *adminv1.UpdateBranchDstCommissionRequest) (*adminv1.UpdateBranchDstCommissionResponse, error)
	UpdateEmployeeAccount(ctx context.Context, req *adminv1.UpdateEmployeeAccountRequest) (*adminv1.UpdateEmployeeAccountResponse, error)
	DeleteEmployeeAccount(ctx context.Context, req *adminv1.DeleteEmployeeAccountRequest) (*adminv1.DeleteEmployeeAccountResponse, error)
	AssignEmployeeBranch(ctx context.Context, req *adminv1.AssignEmployeeBranchRequest) (*adminv1.AssignEmployeeBranchResponse, error)
}

type AdminHandler struct {
	adminv1.UnimplementedAdminServiceServer
	adminService AdminService
}

func NewAdminHandler(adminService AdminService) *AdminHandler {
	return &AdminHandler{adminService: adminService}
}

func (h *AdminHandler) CreateAdminAccount(ctx context.Context, req *adminv1.CreateAdminAccountRequest) (*adminv1.CreateAdminAccountResponse, error) {
	return h.adminService.CreateAdminAccount(ctx, req)
}

func (h *AdminHandler) CreateEmployeeAccount(ctx context.Context, req *adminv1.CreateEmployeeAccountRequest) (*adminv1.CreateEmployeeAccountResponse, error) {
	return h.adminService.CreateEmployeeAccount(ctx, req)
}

func (h *AdminHandler) ListEmployeeAccounts(ctx context.Context, req *adminv1.ListEmployeeAccountsRequest) (*adminv1.ListEmployeeAccountsResponse, error) {
	return h.adminService.ListEmployeeAccounts(ctx, req)
}

func (h *AdminHandler) ListBranchOfficers(ctx context.Context, req *adminv1.ListBranchOfficersRequest) (*adminv1.ListBranchOfficersResponse, error) {
	return h.adminService.ListBranchOfficers(ctx, req)
}

func (h *AdminHandler) CreateDstAccount(ctx context.Context, req *adminv1.CreateDstAccountRequest) (*adminv1.CreateDstAccountResponse, error) {
	return h.adminService.CreateDstAccount(ctx, req)
}

func (h *AdminHandler) UpdateDstAccount(ctx context.Context, req *adminv1.UpdateDstAccountRequest) (*adminv1.UpdateDstAccountResponse, error) {
	return h.adminService.UpdateDstAccount(ctx, req)
}

func (h *AdminHandler) CreateBankBranch(ctx context.Context, req *adminv1.CreateBankBranchRequest) (*adminv1.CreateBankBranchResponse, error) {
	return h.adminService.CreateBankBranch(ctx, req)
}

func (h *AdminHandler) UpdateBankBranch(ctx context.Context, req *adminv1.UpdateBankBranchRequest) (*adminv1.UpdateBankBranchResponse, error) {
	return h.adminService.UpdateBankBranch(ctx, req)
}

func (h *AdminHandler) UpdateBranchDstCommission(ctx context.Context, req *adminv1.UpdateBranchDstCommissionRequest) (*adminv1.UpdateBranchDstCommissionResponse, error) {
	return h.adminService.UpdateBranchDstCommission(ctx, req)
}

func (h *AdminHandler) UpdateEmployeeAccount(ctx context.Context, req *adminv1.UpdateEmployeeAccountRequest) (*adminv1.UpdateEmployeeAccountResponse, error) {
	return h.adminService.UpdateEmployeeAccount(ctx, req)
}

func (h *AdminHandler) AssignEmployeeBranch(ctx context.Context, req *adminv1.AssignEmployeeBranchRequest) (*adminv1.AssignEmployeeBranchResponse, error) {
	return h.adminService.AssignEmployeeBranch(ctx, req)
}

func (h *AdminHandler) DeleteBankBranch(ctx context.Context, req *adminv1.DeleteBankBranchRequest) (*adminv1.DeleteBankBranchResponse, error) {
	return h.adminService.DeleteBankBranch(ctx, req)
}

func (h *AdminHandler) DeleteEmployeeAccount(ctx context.Context, req *adminv1.DeleteEmployeeAccountRequest) (*adminv1.DeleteEmployeeAccountResponse, error) {
	return h.adminService.DeleteEmployeeAccount(ctx, req)
}
