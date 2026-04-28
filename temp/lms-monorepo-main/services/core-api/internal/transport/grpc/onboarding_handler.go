package grpc

import (
	"context"

	onboardingv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/onboardingv1"
)

type OnboardingService interface {
	CompleteBorrowerOnboarding(ctx context.Context, req *onboardingv1.CompleteBorrowerOnboardingRequest) (*onboardingv1.CompleteBorrowerOnboardingResponse, error)
	UpdateBorrowerProfile(ctx context.Context, req *onboardingv1.UpdateBorrowerProfileRequest) (*onboardingv1.UpdateBorrowerProfileResponse, error)
}

type OnboardingHandler struct {
	onboardingv1.UnimplementedOnboardingServiceServer
	onboardingService OnboardingService
}

func NewOnboardingHandler(onboardingService OnboardingService) *OnboardingHandler {
	return &OnboardingHandler{onboardingService: onboardingService}
}

func (h *OnboardingHandler) CompleteBorrowerOnboarding(ctx context.Context, req *onboardingv1.CompleteBorrowerOnboardingRequest) (*onboardingv1.CompleteBorrowerOnboardingResponse, error) {
	return h.onboardingService.CompleteBorrowerOnboarding(ctx, req)
}

func (h *OnboardingHandler) UpdateBorrowerProfile(ctx context.Context, req *onboardingv1.UpdateBorrowerProfileRequest) (*onboardingv1.UpdateBorrowerProfileResponse, error) {
	return h.onboardingService.UpdateBorrowerProfile(ctx, req)
}
