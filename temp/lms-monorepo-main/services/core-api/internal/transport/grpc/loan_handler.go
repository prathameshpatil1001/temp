package grpc

import (
	"context"

	loanv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/loanv1"
)

type LoanService interface {
	CreateLoanProduct(ctx context.Context, req *loanv1.CreateLoanProductRequest) (*loanv1.CreateLoanProductResponse, error)
	UpdateLoanProduct(ctx context.Context, req *loanv1.UpdateLoanProductRequest) (*loanv1.UpdateLoanProductResponse, error)
	DeleteLoanProduct(ctx context.Context, req *loanv1.DeleteLoanProductRequest) (*loanv1.DeleteLoanProductResponse, error)
	GetLoanProduct(ctx context.Context, req *loanv1.GetLoanProductRequest) (*loanv1.GetLoanProductResponse, error)
	ListLoanProducts(ctx context.Context, req *loanv1.ListLoanProductsRequest) (*loanv1.ListLoanProductsResponse, error)
	UpsertProductEligibilityRule(ctx context.Context, req *loanv1.UpsertProductEligibilityRuleRequest) (*loanv1.UpsertProductEligibilityRuleResponse, error)
	ReplaceProductFees(ctx context.Context, req *loanv1.ReplaceProductFeesRequest) (*loanv1.ReplaceProductFeesResponse, error)
	ReplaceProductRequiredDocuments(ctx context.Context, req *loanv1.ReplaceProductRequiredDocumentsRequest) (*loanv1.ReplaceProductRequiredDocumentsResponse, error)
	CreateLoanApplication(ctx context.Context, req *loanv1.CreateLoanApplicationRequest) (*loanv1.CreateLoanApplicationResponse, error)
	GetLoanApplication(ctx context.Context, req *loanv1.GetLoanApplicationRequest) (*loanv1.GetLoanApplicationResponse, error)
	ListLoanApplications(ctx context.Context, req *loanv1.ListLoanApplicationsRequest) (*loanv1.ListLoanApplicationsResponse, error)
	UpdateLoanApplicationStatus(ctx context.Context, req *loanv1.UpdateLoanApplicationStatusRequest) (*loanv1.UpdateLoanApplicationStatusResponse, error)
	UpdateLoanApplicationTerms(ctx context.Context, req *loanv1.UpdateLoanApplicationTermsRequest) (*loanv1.UpdateLoanApplicationTermsResponse, error)
	AssignLoanApplicationOfficer(ctx context.Context, req *loanv1.AssignLoanApplicationOfficerRequest) (*loanv1.AssignLoanApplicationOfficerResponse, error)
	AddApplicationCoapplicant(ctx context.Context, req *loanv1.AddApplicationCoapplicantRequest) (*loanv1.AddApplicationCoapplicantResponse, error)
	UpsertApplicationCollateral(ctx context.Context, req *loanv1.UpsertApplicationCollateralRequest) (*loanv1.UpsertApplicationCollateralResponse, error)
	UpsertLoanVehicle(ctx context.Context, req *loanv1.UpsertLoanVehicleRequest) (*loanv1.UpsertLoanVehicleResponse, error)
	UpsertLoanRealEstate(ctx context.Context, req *loanv1.UpsertLoanRealEstateRequest) (*loanv1.UpsertLoanRealEstateResponse, error)
	AddApplicationDocument(ctx context.Context, req *loanv1.AddApplicationDocumentRequest) (*loanv1.AddApplicationDocumentResponse, error)
	UpdateApplicationDocumentVerification(ctx context.Context, req *loanv1.UpdateApplicationDocumentVerificationRequest) (*loanv1.UpdateApplicationDocumentVerificationResponse, error)
	AddBureauScore(ctx context.Context, req *loanv1.AddBureauScoreRequest) (*loanv1.AddBureauScoreResponse, error)
	CreateLoan(ctx context.Context, req *loanv1.CreateLoanRequest) (*loanv1.CreateLoanResponse, error)
	GetLoan(ctx context.Context, req *loanv1.GetLoanRequest) (*loanv1.GetLoanResponse, error)
	ListLoans(ctx context.Context, req *loanv1.ListLoansRequest) (*loanv1.ListLoansResponse, error)
	AddEmiScheduleItem(ctx context.Context, req *loanv1.AddEmiScheduleItemRequest) (*loanv1.AddEmiScheduleItemResponse, error)
	ListEmiSchedule(ctx context.Context, req *loanv1.ListEmiScheduleRequest) (*loanv1.ListEmiScheduleResponse, error)
	RecordPayment(ctx context.Context, req *loanv1.RecordPaymentRequest) (*loanv1.RecordPaymentResponse, error)
	ListPayments(ctx context.Context, req *loanv1.ListPaymentsRequest) (*loanv1.ListPaymentsResponse, error)
	RescheduleLoan(ctx context.Context, req *loanv1.RescheduleLoanRequest) (*loanv1.RescheduleLoanResponse, error)
	InitiatePayment(ctx context.Context, req *loanv1.InitiatePaymentRequest) (*loanv1.InitiatePaymentResponse, error)
	VerifyPayment(ctx context.Context, req *loanv1.VerifyPaymentRequest) (*loanv1.VerifyPaymentResponse, error)
	ProcessPaymentFromWebhook(ctx context.Context, orderID, paymentID string) error
}

type LoanHandler struct {
	loanv1.UnimplementedLoanServiceServer
	loanService LoanService
}

func NewLoanHandler(loanService LoanService) *LoanHandler {
	return &LoanHandler{loanService: loanService}
}

func (h *LoanHandler) CreateLoanProduct(ctx context.Context, req *loanv1.CreateLoanProductRequest) (*loanv1.CreateLoanProductResponse, error) {
	return h.loanService.CreateLoanProduct(ctx, req)
}
func (h *LoanHandler) UpdateLoanProduct(ctx context.Context, req *loanv1.UpdateLoanProductRequest) (*loanv1.UpdateLoanProductResponse, error) {
	return h.loanService.UpdateLoanProduct(ctx, req)
}
func (h *LoanHandler) DeleteLoanProduct(ctx context.Context, req *loanv1.DeleteLoanProductRequest) (*loanv1.DeleteLoanProductResponse, error) {
	return h.loanService.DeleteLoanProduct(ctx, req)
}
func (h *LoanHandler) GetLoanProduct(ctx context.Context, req *loanv1.GetLoanProductRequest) (*loanv1.GetLoanProductResponse, error) {
	return h.loanService.GetLoanProduct(ctx, req)
}
func (h *LoanHandler) ListLoanProducts(ctx context.Context, req *loanv1.ListLoanProductsRequest) (*loanv1.ListLoanProductsResponse, error) {
	return h.loanService.ListLoanProducts(ctx, req)
}
func (h *LoanHandler) UpsertProductEligibilityRule(ctx context.Context, req *loanv1.UpsertProductEligibilityRuleRequest) (*loanv1.UpsertProductEligibilityRuleResponse, error) {
	return h.loanService.UpsertProductEligibilityRule(ctx, req)
}
func (h *LoanHandler) ReplaceProductFees(ctx context.Context, req *loanv1.ReplaceProductFeesRequest) (*loanv1.ReplaceProductFeesResponse, error) {
	return h.loanService.ReplaceProductFees(ctx, req)
}
func (h *LoanHandler) ReplaceProductRequiredDocuments(ctx context.Context, req *loanv1.ReplaceProductRequiredDocumentsRequest) (*loanv1.ReplaceProductRequiredDocumentsResponse, error) {
	return h.loanService.ReplaceProductRequiredDocuments(ctx, req)
}
func (h *LoanHandler) CreateLoanApplication(ctx context.Context, req *loanv1.CreateLoanApplicationRequest) (*loanv1.CreateLoanApplicationResponse, error) {
	return h.loanService.CreateLoanApplication(ctx, req)
}
func (h *LoanHandler) GetLoanApplication(ctx context.Context, req *loanv1.GetLoanApplicationRequest) (*loanv1.GetLoanApplicationResponse, error) {
	return h.loanService.GetLoanApplication(ctx, req)
}
func (h *LoanHandler) ListLoanApplications(ctx context.Context, req *loanv1.ListLoanApplicationsRequest) (*loanv1.ListLoanApplicationsResponse, error) {
	return h.loanService.ListLoanApplications(ctx, req)
}
func (h *LoanHandler) UpdateLoanApplicationStatus(ctx context.Context, req *loanv1.UpdateLoanApplicationStatusRequest) (*loanv1.UpdateLoanApplicationStatusResponse, error) {
	return h.loanService.UpdateLoanApplicationStatus(ctx, req)
}
func (h *LoanHandler) UpdateLoanApplicationTerms(ctx context.Context, req *loanv1.UpdateLoanApplicationTermsRequest) (*loanv1.UpdateLoanApplicationTermsResponse, error) {
	return h.loanService.UpdateLoanApplicationTerms(ctx, req)
}
func (h *LoanHandler) AssignLoanApplicationOfficer(ctx context.Context, req *loanv1.AssignLoanApplicationOfficerRequest) (*loanv1.AssignLoanApplicationOfficerResponse, error) {
	return h.loanService.AssignLoanApplicationOfficer(ctx, req)
}
func (h *LoanHandler) AddApplicationCoapplicant(ctx context.Context, req *loanv1.AddApplicationCoapplicantRequest) (*loanv1.AddApplicationCoapplicantResponse, error) {
	return h.loanService.AddApplicationCoapplicant(ctx, req)
}
func (h *LoanHandler) UpsertApplicationCollateral(ctx context.Context, req *loanv1.UpsertApplicationCollateralRequest) (*loanv1.UpsertApplicationCollateralResponse, error) {
	return h.loanService.UpsertApplicationCollateral(ctx, req)
}
func (h *LoanHandler) UpsertLoanVehicle(ctx context.Context, req *loanv1.UpsertLoanVehicleRequest) (*loanv1.UpsertLoanVehicleResponse, error) {
	return h.loanService.UpsertLoanVehicle(ctx, req)
}
func (h *LoanHandler) UpsertLoanRealEstate(ctx context.Context, req *loanv1.UpsertLoanRealEstateRequest) (*loanv1.UpsertLoanRealEstateResponse, error) {
	return h.loanService.UpsertLoanRealEstate(ctx, req)
}
func (h *LoanHandler) AddApplicationDocument(ctx context.Context, req *loanv1.AddApplicationDocumentRequest) (*loanv1.AddApplicationDocumentResponse, error) {
	return h.loanService.AddApplicationDocument(ctx, req)
}
func (h *LoanHandler) UpdateApplicationDocumentVerification(ctx context.Context, req *loanv1.UpdateApplicationDocumentVerificationRequest) (*loanv1.UpdateApplicationDocumentVerificationResponse, error) {
	return h.loanService.UpdateApplicationDocumentVerification(ctx, req)
}
func (h *LoanHandler) AddBureauScore(ctx context.Context, req *loanv1.AddBureauScoreRequest) (*loanv1.AddBureauScoreResponse, error) {
	return h.loanService.AddBureauScore(ctx, req)
}
func (h *LoanHandler) CreateLoan(ctx context.Context, req *loanv1.CreateLoanRequest) (*loanv1.CreateLoanResponse, error) {
	return h.loanService.CreateLoan(ctx, req)
}
func (h *LoanHandler) GetLoan(ctx context.Context, req *loanv1.GetLoanRequest) (*loanv1.GetLoanResponse, error) {
	return h.loanService.GetLoan(ctx, req)
}
func (h *LoanHandler) ListLoans(ctx context.Context, req *loanv1.ListLoansRequest) (*loanv1.ListLoansResponse, error) {
	return h.loanService.ListLoans(ctx, req)
}
func (h *LoanHandler) AddEmiScheduleItem(ctx context.Context, req *loanv1.AddEmiScheduleItemRequest) (*loanv1.AddEmiScheduleItemResponse, error) {
	return h.loanService.AddEmiScheduleItem(ctx, req)
}
func (h *LoanHandler) ListEmiSchedule(ctx context.Context, req *loanv1.ListEmiScheduleRequest) (*loanv1.ListEmiScheduleResponse, error) {
	return h.loanService.ListEmiSchedule(ctx, req)
}
func (h *LoanHandler) RecordPayment(ctx context.Context, req *loanv1.RecordPaymentRequest) (*loanv1.RecordPaymentResponse, error) {
	return h.loanService.RecordPayment(ctx, req)
}
func (h *LoanHandler) ListPayments(ctx context.Context, req *loanv1.ListPaymentsRequest) (*loanv1.ListPaymentsResponse, error) {
	return h.loanService.ListPayments(ctx, req)
}
func (h *LoanHandler) RescheduleLoan(ctx context.Context, req *loanv1.RescheduleLoanRequest) (*loanv1.RescheduleLoanResponse, error) {
	return h.loanService.RescheduleLoan(ctx, req)
}
func (h *LoanHandler) InitiatePayment(ctx context.Context, req *loanv1.InitiatePaymentRequest) (*loanv1.InitiatePaymentResponse, error) {
	return h.loanService.InitiatePayment(ctx, req)
}
func (h *LoanHandler) VerifyPayment(ctx context.Context, req *loanv1.VerifyPaymentRequest) (*loanv1.VerifyPaymentResponse, error) {
	return h.loanService.VerifyPayment(ctx, req)
}
