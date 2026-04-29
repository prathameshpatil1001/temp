package grpc

import (
	"context"

	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type AuthService interface {
	Hello(ctx context.Context, name string) (string, error)
	InitiateSignup(ctx context.Context, req *authv1.SignupRequest) (*authv1.SignupResponse, error)
	VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error)
	SetupTOTP(ctx context.Context, req *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error)
	VerifyTOTPSetup(ctx context.Context, req *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error)
	LoginPrimary(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error)
	InitiateReopen(ctx context.Context, req *authv1.InitiateReopenRequest) (*authv1.LoginPrimaryResponse, error)
	SelectLoginMFAFactor(ctx context.Context, req *authv1.SelectLoginMFAFactorRequest) (*authv1.SelectLoginMFAFactorResponse, error)
	VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error)
	ChangePassword(ctx context.Context, req *authv1.ChangePasswordRequest) (*authv1.ChangePasswordResponse, error)
	InitiateForgotPassword(ctx context.Context, req *authv1.InitiateForgotPasswordRequest) (*authv1.InitiateForgotPasswordResponse, error)
	VerifyForgotPasswordOTPs(ctx context.Context, req *authv1.VerifyForgotPasswordOTPsRequest) (*authv1.VerifyForgotPasswordOTPsResponse, error)
	ResetForgotPassword(ctx context.Context, req *authv1.ResetForgotPasswordRequest) (*authv1.ResetForgotPasswordResponse, error)
	BeginWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error)
	FinishWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnFinishRegRequest) (*authv1.AuthTokens, error)
	BeginWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error)
	FinishWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnFinishLoginRequest) (*authv1.AuthTokens, error)
	GetMyProfile(ctx context.Context, req *authv1.GetMyProfileRequest) (*authv1.GetMyProfileResponse, error)
	GetBorrowerProfile(ctx context.Context, req *authv1.GetBorrowerProfileRequest) (*authv1.BorrowerProfile, error)
	GetUser(ctx context.Context, req *authv1.GetUserRequest) (*authv1.GetUserResponse, error)
	GetOfficerProfileByUserID(ctx context.Context, req *authv1.GetUserRequest) (*authv1.OfficerProfile, error)
	GetManagerProfileByUserID(ctx context.Context, req *authv1.GetUserRequest) (*authv1.ManagerProfile, error)
	SearchBorrowerSignupStatus(ctx context.Context, req *authv1.SearchBorrowerSignupStatusRequest) (*authv1.SearchBorrowerSignupStatusResponse, error)
	RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error)
	Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error)
}

type AuthHandler struct {
	authv1.UnimplementedAuthServiceServer
	authService AuthService
}

func NewAuthHandler(authService AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

func (h *AuthHandler) Hello(ctx context.Context, req *authv1.HelloRequest) (*authv1.HelloResponse, error) {
	msg, err := h.authService.Hello(ctx, req.GetName())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to process hello")
	}
	return &authv1.HelloResponse{Message: msg}, nil
}

func (h *AuthHandler) InitiateSignup(ctx context.Context, req *authv1.SignupRequest) (*authv1.SignupResponse, error) {
	return h.authService.InitiateSignup(ctx, req)
}

func (h *AuthHandler) VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error) {
	return h.authService.VerifySignupOTPs(ctx, req)
}

func (h *AuthHandler) SetupTOTP(ctx context.Context, req *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error) {
	return h.authService.SetupTOTP(ctx, req)
}

func (h *AuthHandler) VerifyTOTPSetup(ctx context.Context, req *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error) {
	return h.authService.VerifyTOTPSetup(ctx, req)
}

func (h *AuthHandler) LoginPrimary(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error) {
	return h.authService.LoginPrimary(ctx, req)
}

func (h *AuthHandler) InitiateReopen(ctx context.Context, req *authv1.InitiateReopenRequest) (*authv1.LoginPrimaryResponse, error) {
	return h.authService.InitiateReopen(ctx, req)
}

func (h *AuthHandler) SelectLoginMFAFactor(ctx context.Context, req *authv1.SelectLoginMFAFactorRequest) (*authv1.SelectLoginMFAFactorResponse, error) {
	return h.authService.SelectLoginMFAFactor(ctx, req)
}

func (h *AuthHandler) VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error) {
	return h.authService.VerifyLoginMFA(ctx, req)
}

func (h *AuthHandler) ChangePassword(ctx context.Context, req *authv1.ChangePasswordRequest) (*authv1.ChangePasswordResponse, error) {
	return h.authService.ChangePassword(ctx, req)
}

func (h *AuthHandler) InitiateForgotPassword(ctx context.Context, req *authv1.InitiateForgotPasswordRequest) (*authv1.InitiateForgotPasswordResponse, error) {
	return h.authService.InitiateForgotPassword(ctx, req)
}

func (h *AuthHandler) VerifyForgotPasswordOTPs(ctx context.Context, req *authv1.VerifyForgotPasswordOTPsRequest) (*authv1.VerifyForgotPasswordOTPsResponse, error) {
	return h.authService.VerifyForgotPasswordOTPs(ctx, req)
}

func (h *AuthHandler) ResetForgotPassword(ctx context.Context, req *authv1.ResetForgotPasswordRequest) (*authv1.ResetForgotPasswordResponse, error) {
	return h.authService.ResetForgotPassword(ctx, req)
}

func (h *AuthHandler) GetMyProfile(ctx context.Context, req *authv1.GetMyProfileRequest) (*authv1.GetMyProfileResponse, error) {
	return h.authService.GetMyProfile(ctx, req)
}

func (h *AuthHandler) GetBorrowerProfile(ctx context.Context, req *authv1.GetBorrowerProfileRequest) (*authv1.BorrowerProfile, error) {
	return h.authService.GetBorrowerProfile(ctx, req)
}

func (h *AuthHandler) GetUser(ctx context.Context, req *authv1.GetUserRequest) (*authv1.GetUserResponse, error) {
	return h.authService.GetUser(ctx, req)
}

func (h *AuthHandler) GetOfficerProfileByUserID(ctx context.Context, req *authv1.GetUserRequest) (*authv1.OfficerProfile, error) {
	return h.authService.GetOfficerProfileByUserID(ctx, req)
}

func (h *AuthHandler) GetManagerProfileByUserID(ctx context.Context, req *authv1.GetUserRequest) (*authv1.ManagerProfile, error) {
	return h.authService.GetManagerProfileByUserID(ctx, req)
}

func (h *AuthHandler) SearchBorrowerSignupStatus(ctx context.Context, req *authv1.SearchBorrowerSignupStatusRequest) (*authv1.SearchBorrowerSignupStatusResponse, error) {
	return h.authService.SearchBorrowerSignupStatus(ctx, req)
}

func (h *AuthHandler) RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error) {
	return h.authService.RefreshToken(ctx, req)
}

func (h *AuthHandler) Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	return h.authService.Logout(ctx, req)
}

func (h *AuthHandler) FinishWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnFinishRegRequest) (*authv1.AuthTokens, error) {
	return h.authService.FinishWebAuthnRegistration(ctx, req)
}

func (h *AuthHandler) BeginWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error) {
	return h.authService.BeginWebAuthnLogin(ctx, req)
}

func (h *AuthHandler) FinishWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnFinishLoginRequest) (*authv1.AuthTokens, error) {
	return h.authService.FinishWebAuthnLogin(ctx, req)
}

func (h *AuthHandler) BeginWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error) {
	return h.authService.BeginWebAuthnRegistration(ctx, req)
}
