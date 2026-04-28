package grpc

import (
	"context"

	kycv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/kycv1"
)

type KycService interface {
	RecordUserConsent(ctx context.Context, req *kycv1.RecordUserConsentRequest) (*kycv1.RecordUserConsentResponse, error)
	InitiateAadhaarKyc(ctx context.Context, req *kycv1.InitiateAadhaarKycRequest) (*kycv1.InitiateAadhaarKycResponse, error)
	VerifyAadhaarKycOtp(ctx context.Context, req *kycv1.VerifyAadhaarKycOtpRequest) (*kycv1.VerifyAadhaarKycOtpResponse, error)
	VerifyPanKyc(ctx context.Context, req *kycv1.VerifyPanKycRequest) (*kycv1.VerifyPanKycResponse, error)
	GetBorrowerKycStatus(ctx context.Context, req *kycv1.GetBorrowerKycStatusRequest) (*kycv1.GetBorrowerKycStatusResponse, error)
	ListBorrowerKycHistory(ctx context.Context, req *kycv1.ListBorrowerKycHistoryRequest) (*kycv1.ListBorrowerKycHistoryResponse, error)
}

type KycHandler struct {
	kycv1.UnimplementedKycServiceServer
	kycService KycService
}

func NewKycHandler(kycService KycService) *KycHandler {
	return &KycHandler{kycService: kycService}
}

func (h *KycHandler) RecordUserConsent(ctx context.Context, req *kycv1.RecordUserConsentRequest) (*kycv1.RecordUserConsentResponse, error) {
	return h.kycService.RecordUserConsent(ctx, req)
}

func (h *KycHandler) InitiateAadhaarKyc(ctx context.Context, req *kycv1.InitiateAadhaarKycRequest) (*kycv1.InitiateAadhaarKycResponse, error) {
	return h.kycService.InitiateAadhaarKyc(ctx, req)
}

func (h *KycHandler) VerifyAadhaarKycOtp(ctx context.Context, req *kycv1.VerifyAadhaarKycOtpRequest) (*kycv1.VerifyAadhaarKycOtpResponse, error) {
	return h.kycService.VerifyAadhaarKycOtp(ctx, req)
}

func (h *KycHandler) VerifyPanKyc(ctx context.Context, req *kycv1.VerifyPanKycRequest) (*kycv1.VerifyPanKycResponse, error) {
	return h.kycService.VerifyPanKyc(ctx, req)
}

func (h *KycHandler) GetBorrowerKycStatus(ctx context.Context, req *kycv1.GetBorrowerKycStatusRequest) (*kycv1.GetBorrowerKycStatusResponse, error) {
	return h.kycService.GetBorrowerKycStatus(ctx, req)
}

func (h *KycHandler) ListBorrowerKycHistory(ctx context.Context, req *kycv1.ListBorrowerKycHistoryRequest) (*kycv1.ListBorrowerKycHistoryResponse, error) {
	return h.kycService.ListBorrowerKycHistory(ctx, req)
}
