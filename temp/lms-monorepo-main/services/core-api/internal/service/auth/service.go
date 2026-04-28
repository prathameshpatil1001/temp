package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"strconv"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/config"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/security/argon2"
	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/util"
	"github.com/go-webauthn/webauthn/protocol"
	"github.com/go-webauthn/webauthn/webauthn"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/pquerna/otp/totp"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
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
	GetMyProfile(ctx context.Context, req *authv1.GetMyProfileRequest) (*authv1.GetMyProfileResponse, error)
	GetBorrowerProfile(ctx context.Context, req *authv1.GetBorrowerProfileRequest) (*authv1.BorrowerProfile, error)
	GetUser(ctx context.Context, req *authv1.GetUserRequest) (*authv1.GetUserResponse, error)
	SearchBorrowerSignupStatus(ctx context.Context, req *authv1.SearchBorrowerSignupStatusRequest) (*authv1.SearchBorrowerSignupStatusResponse, error)
	RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error)
	Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error)
	BeginWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error)
	FinishWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnFinishRegRequest) (*authv1.AuthTokens, error)
	BeginWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error)
	FinishWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnFinishLoginRequest) (*authv1.AuthTokens, error)
}

type service struct {
	queries  generated.Querier
	redis    redis.Cmdable
	cfg      config.Config
	webauthn *webauthn.WebAuthn
}

const (
	mfaFactorTOTP     = "totp"
	mfaFactorEmailOTP = "email_otp"
	mfaFactorPhoneOTP = "phone_otp"
	mfaFactorWebAuthn = "webauthn"

	mfaSessionTTL      = 5 * time.Minute
	mfaChallengeTTL    = 5 * time.Minute
	mfaChallengeMaxTry = 5

	mfaFlowPrimary = "login_primary"
	mfaFlowReopen  = "reopen"
)

type mfaSessionState struct {
	UserID         string   `json:"user_id"`
	Role           string   `json:"role"`
	Email          string   `json:"email"`
	Phone          string   `json:"phone"`
	AllowedFactors []string `json:"allowed_factors"`
	SelectedFactor string   `json:"selected_factor"`
	WebauthnUserID string   `json:"webauthn_user_id"`
	Flow           string   `json:"flow"`
	RefreshHash    string   `json:"refresh_hash,omitempty"`
	BoundDeviceID  string   `json:"bound_device_id,omitempty"`
}

type mfaOTPChallenge struct {
	Factor    string `json:"factor"`
	OTPHash   string `json:"otp_hash"`
	Attempts  int    `json:"attempts"`
	MaxTry    int    `json:"max_try"`
	ExpiresAt int64  `json:"expires_at"`
}

type forgotPasswordSession struct {
	UserID      string `json:"user_id"`
	Email       string `json:"email"`
	Phone       string `json:"phone"`
	EmailOTP    string `json:"email_otp"`
	PhoneOTP    string `json:"phone_otp"`
	IsVerified  bool   `json:"is_verified"`
	AttemptLeft int    `json:"attempt_left"`
}

type webauthnLoginSession struct {
	UserID  string               `json:"user_id"`
	Session webauthn.SessionData `json:"session"`
}

// NewService constructs the auth service with repository, redis, and runtime config dependencies.
func NewService(queries generated.Querier, redis redis.Cmdable, cfg config.Config) Service {
	origins := []string{}
	for _, origin := range strings.Split(cfg.WebAuthnRPOrigins, ",") {
		trimmed := strings.TrimSpace(origin)
		if trimmed != "" {
			origins = append(origins, trimmed)
		}
	}
	if len(origins) == 0 {
		origins = []string{"http://localhost:3000"}
	}

	w, _ := webauthn.New(&webauthn.Config{
		RPDisplayName: cfg.WebAuthnRPDisplayName,
		RPID:          cfg.WebAuthnRPID,
		RPOrigins:     origins,
	})

	return &service{
		queries:  queries,
		redis:    redis,
		cfg:      cfg,
		webauthn: w,
	}
}

func (s *service) Hello(ctx context.Context, name string) (string, error) {
	_ = ctx
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		trimmed = "world"
	}
	return "hello " + trimmed, nil
}

// InitiateSignup creates an unverified user session and starts a short-lived OTP verification session.
func (s *service) InitiateSignup(ctx context.Context, req *authv1.SignupRequest) (*authv1.SignupResponse, error) {
	_, err := s.queries.GetUserByEmailOrPhone(ctx, req.GetEmail())
	if err == nil {
		return nil, status.Error(codes.AlreadyExists, "email or phone already registered")
	}
	_, err = s.queries.GetUserByEmailOrPhone(ctx, req.GetPhone())
	if err == nil {
		return nil, status.Error(codes.AlreadyExists, "email or phone already registered")
	}

	hash, err := argon2.HashPassword(req.GetPassword(), argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	// Uncomment this after otp sender integrations
	//emailOTP := generateOTP()
	//phoneOTP := generateOTP()

	//Comment this after otp sender integrations
	emailOTP := "123456"
	phoneOTP := "123456"

	regID := uuid.New().String()
	regData, _ := json.Marshal(map[string]string{
		"email":         req.GetEmail(),
		"phone":         req.GetPhone(),
		"password_hash": hash,
		"email_otp":     emailOTP,
		"phone_otp":     phoneOTP,
	})

	err = s.redis.Set(ctx, fmt.Sprintf("signup_reg:%s", regID), regData, 10*time.Minute).Err()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to store registration state")
	}

	fmt.Printf("DEBUG: Email OTP for %s: %s\n", req.GetEmail(), emailOTP)
	fmt.Printf("DEBUG: Phone OTP for %s: %s\n", req.GetPhone(), phoneOTP)

	return &authv1.SignupResponse{
		RegistrationId: regID,
	}, nil
}

// VerifySignupOTPs validates email/phone OTPs, creates the user, and marks them as verified.
// Activation remains false until role-specific onboarding is completed.
func (s *service) VerifySignupOTPs(ctx context.Context, req *authv1.VerifyOTPsRequest) (*authv1.VerifyOTPsResponse, error) {
	key := fmt.Sprintf("signup_reg:%s", req.GetRegistrationId())
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, status.Error(codes.NotFound, "registration session expired or invalid")
		}
		return nil, status.Error(codes.Internal, "failed to retrieve registration state")
	}

	var data map[string]string
	if err := json.Unmarshal([]byte(val), &data); err != nil {
		return nil, status.Error(codes.Internal, "corrupt registration state")
	}

	if req.GetEmailCode() != data["email_otp"] || req.GetPhoneCode() != data["phone_otp"] {
		return nil, status.Error(codes.InvalidArgument, "invalid verification codes")
	}

	user, err := s.queries.CreateUser(ctx, generated.CreateUserParams{
		Email:        data["email"],
		Phone:        data["phone"],
		PasswordHash: data["password_hash"],
		Role:         generated.UserRoleBorrower,
	})
	if err != nil {
		if strings.Contains(err.Error(), "users_email_key") {
			return nil, status.Error(codes.AlreadyExists, "email already registered")
		}
		if strings.Contains(err.Error(), "users_phone_key") {
			return nil, status.Error(codes.AlreadyExists, "phone number already registered")
		}
		return nil, status.Error(codes.Internal, "failed to create user")
	}

	err = s.queries.UpdateUserVerification(ctx, generated.UpdateUserVerificationParams{
		ID:              user.ID,
		IsActive:        pgtype.Bool{Bool: false, Valid: true},
		IsEmailVerified: pgtype.Bool{Bool: true, Valid: true},
		IsPhoneVerified: pgtype.Bool{Bool: true, Valid: true},
	})

	if err != nil {
		return nil, status.Error(codes.Internal, "failed to verify user")
	}

	s.redis.Del(ctx, key)

	return &authv1.VerifyOTPsResponse{Verified: true}, nil
}

// SetupTOTP creates a TOTP secret for the authenticated user.
func (s *service) SetupTOTP(ctx context.Context, req *authv1.SetupTOTPRequest) (*authv1.SetupTOTPResponse, error) {
	_ = req
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "user not found in context")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "LMS-Core",
		AccountName: user.Email,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate totp secret")
	}

	err = s.queries.SetTOTPSecret(ctx, generated.SetTOTPSecretParams{
		ID:         pgtype.UUID{Bytes: userID, Valid: true},
		TotpSecret: pgtype.Text{String: key.Secret(), Valid: true},
		HasTotp:    pgtype.Bool{Bool: false, Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to save totp secret")
	}

	return &authv1.SetupTOTPResponse{
		Secret:          key.Secret(),
		ProvisioningUri: key.URL(),
	}, nil
}

// VerifyTOTPSetup validates the submitted TOTP code and enables TOTP for future logins.
func (s *service) VerifyTOTPSetup(ctx context.Context, req *authv1.VerifyTOTPSetupRequest) (*authv1.AuthTokens, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "user not found in context")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	if !totp.Validate(req.GetCode(), user.TotpSecret.String) {
		return nil, status.Error(codes.InvalidArgument, "invalid totp code")
	}

	err = s.queries.SetTOTPSecret(ctx, generated.SetTOTPSecretParams{
		ID:         pgtype.UUID{Bytes: userID, Valid: true},
		TotpSecret: user.TotpSecret,
		HasTotp:    pgtype.Bool{Bool: true, Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to finalize totp setup")
	}

	return s.mintTokens(ctx, userID, string(user.Role), req.GetDeviceId())
}

// LoginPrimary verifies username/password and returns an MFA session with allowed factors.
func (s *service) LoginPrimary(ctx context.Context, req *authv1.LoginRequest) (*authv1.LoginPrimaryResponse, error) {
	user, err := s.queries.GetUserByEmailOrPhone(ctx, req.GetEmailOrPhone())
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid credentials")
	}

	match, err := argon2.VerifyPassword(req.GetPassword(), user.PasswordHash)
	if err != nil || !match {
		return nil, status.Error(codes.Unauthenticated, "invalid credentials")
	}

	mfaSessionID := uuid.New().String()
	allowedFactors, err := s.loadAllowedFactors(ctx, user)
	if err != nil {
		return nil, err
	}

	if len(allowedFactors) == 0 {
		return nil, status.Error(codes.FailedPrecondition, "no mfa factors available")
	}

	mfaData, err := json.Marshal(mfaSessionState{
		UserID:         user.ID.String(),
		Role:           string(user.Role),
		Email:          user.Email,
		Phone:          user.Phone,
		AllowedFactors: allowedFactors,
		WebauthnUserID: user.ID.String(),
		Flow:           mfaFlowPrimary,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to encode mfa session")
	}

	err = s.redis.Set(ctx, fmt.Sprintf("mfa_session:%s", mfaSessionID), mfaData, mfaSessionTTL).Err()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create mfa session")
	}

	return &authv1.LoginPrimaryResponse{
		MfaSessionId:              mfaSessionID,
		AllowedFactors:            allowedFactors,
		IsRequiringPasswordChange: user.IsRequiringPasswordChange.Bool,
	}, nil
}

// InitiateReopen starts a passwordless reopen flow by validating refresh token and requiring MFA step-up.
func (s *service) InitiateReopen(ctx context.Context, req *authv1.InitiateReopenRequest) (*authv1.LoginPrimaryResponse, error) {
	refreshToken := strings.TrimSpace(req.GetRefreshToken())
	deviceID := strings.TrimSpace(req.GetDeviceId())
	if refreshToken == "" || deviceID == "" {
		return nil, status.Error(codes.InvalidArgument, "refresh_token and device_id are required")
	}

	refreshHash := hashRefreshToken(refreshToken)
	tokenRecord, err := s.queries.GetRefreshTokenByHashedTokenAny(ctx, refreshHash)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid refresh token")
	}

	if tokenRecord.IsRevoked.Bool {
		return nil, status.Error(codes.Unauthenticated, "session logged out; password login required")
	}
	if isRefreshTokenExpired(tokenRecord.ExpiresAt) {
		return nil, status.Error(codes.Unauthenticated, "session expired; password login required")
	}
	if tokenRecord.DeviceID != deviceID {
		return nil, status.Error(codes.Unauthenticated, "invalid device id")
	}

	userID := uuid.UUID(tokenRecord.UserID.Bytes)
	user, err := s.queries.GetUserByID(ctx, tokenRecord.UserID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	allowedFactors, err := s.loadAllowedFactors(ctx, user)
	if err != nil {
		return nil, err
	}
	if len(allowedFactors) == 0 {
		return nil, status.Error(codes.FailedPrecondition, "no mfa factors available")
	}

	mfaSessionID := uuid.New().String()
	mfaData, err := json.Marshal(mfaSessionState{
		UserID:         userID.String(),
		Role:           string(user.Role),
		Email:          user.Email,
		Phone:          user.Phone,
		AllowedFactors: allowedFactors,
		WebauthnUserID: userID.String(),
		Flow:           mfaFlowReopen,
		RefreshHash:    refreshHash,
		BoundDeviceID:  deviceID,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to encode mfa session")
	}

	if err := s.redis.Set(ctx, fmt.Sprintf("mfa_session:%s", mfaSessionID), mfaData, mfaSessionTTL).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to create mfa session")
	}

	return &authv1.LoginPrimaryResponse{
		MfaSessionId:              mfaSessionID,
		AllowedFactors:            allowedFactors,
		IsRequiringPasswordChange: user.IsRequiringPasswordChange.Bool,
	}, nil
}

// SelectLoginMFAFactor stores the selected MFA factor and issues an OTP challenge when required.
func (s *service) SelectLoginMFAFactor(ctx context.Context, req *authv1.SelectLoginMFAFactorRequest) (*authv1.SelectLoginMFAFactorResponse, error) {
	session, err := s.getMFASession(ctx, req.GetMfaSessionId())
	if err != nil {
		return nil, err
	}

	factor := strings.TrimSpace(strings.ToLower(req.GetFactor()))
	if factor == "" {
		return nil, status.Error(codes.InvalidArgument, "mfa factor is required")
	}

	if !containsString(session.AllowedFactors, factor) {
		return nil, status.Error(codes.InvalidArgument, "selected mfa factor is not allowed")
	}

	challengeSent := false
	challengeTarget := ""
	webauthnRequestOptions := []byte{}

	session.SelectedFactor = factor

	switch factor {
	case mfaFactorTOTP:
		// No out-of-band challenge required.
	case mfaFactorWebAuthn:
		beginResp, err := s.BeginWebAuthnLogin(ctx, &authv1.WebAuthnLoginRequest{UserId: session.WebauthnUserID})
		if err != nil {
			return nil, err
		}
		session.SelectedFactor = mfaFactorWebAuthn
		if beginResp.GetMfaSessionId() == "" {
			return nil, status.Error(codes.Internal, "webauthn login session missing")
		}
		if beginResp.GetMfaSessionId() != req.GetMfaSessionId() {
			originalChallenge, err := s.redis.Get(ctx, fmt.Sprintf("webauthn_login:%s", beginResp.GetMfaSessionId())).Result()
			if err != nil {
				return nil, status.Error(codes.Internal, "failed to load generated webauthn challenge")
			}
			if err := s.redis.Set(ctx, fmt.Sprintf("webauthn_login:%s", req.GetMfaSessionId()), originalChallenge, mfaSessionTTL).Err(); err != nil {
				return nil, status.Error(codes.Internal, "failed to link webauthn challenge")
			}
			_ = s.redis.Del(ctx, fmt.Sprintf("webauthn_login:%s", beginResp.GetMfaSessionId())).Err()
		}
		webauthnRequestOptions = beginResp.GetPublicKeyCredentialRequestOptions()
	case mfaFactorEmailOTP, mfaFactorPhoneOTP:
		// Uncomment this on sender integration
		//otp := generateOTP()

		// Comment this on sender integration
		otp := "123456"
		challenge := mfaOTPChallenge{
			Factor:    factor,
			OTPHash:   hashOTP(otp),
			Attempts:  0,
			MaxTry:    mfaChallengeMaxTry,
			ExpiresAt: time.Now().Add(mfaChallengeTTL).Unix(),
		}

		challengeJSON, err := json.Marshal(challenge)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to encode mfa challenge")
		}

		if err := s.redis.Set(ctx, fmt.Sprintf("mfa_challenge:%s", req.GetMfaSessionId()), challengeJSON, mfaChallengeTTL).Err(); err != nil {
			return nil, status.Error(codes.Internal, "failed to create mfa challenge")
		}

		challengeSent = true
		if factor == mfaFactorEmailOTP {
			challengeTarget = maskEmail(session.Email)
			fmt.Printf("DEBUG: Login Email OTP for %s: %s\n", session.Email, otp)
		} else {
			challengeTarget = maskPhone(session.Phone)
			fmt.Printf("DEBUG: Login Phone OTP for %s: %s\n", session.Phone, otp)
		}
	default:
		return nil, status.Error(codes.InvalidArgument, "unsupported mfa factor")
	}

	if err := s.setMFASession(ctx, req.GetMfaSessionId(), session); err != nil {
		return nil, err
	}

	return &authv1.SelectLoginMFAFactorResponse{
		ChallengeSent:          challengeSent,
		ChallengeTarget:        challengeTarget,
		WebauthnRequestOptions: webauthnRequestOptions,
	}, nil
}

// VerifyLoginMFA validates the selected MFA factor and mints access/refresh tokens on success.
func (s *service) VerifyLoginMFA(ctx context.Context, req *authv1.VerifyLoginMFARequest) (*authv1.AuthTokens, error) {
	session, err := s.getMFASession(ctx, req.GetMfaSessionId())
	if err != nil {
		return nil, err
	}
	if session.SelectedFactor == "" {
		return nil, status.Error(codes.FailedPrecondition, "mfa factor not selected")
	}

	userID, err := uuid.Parse(session.UserID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid mfa user id")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	switch session.SelectedFactor {
	case mfaFactorTOTP:
		f, ok := req.Factor.(*authv1.VerifyLoginMFARequest_TotpCode)
		if !ok || strings.TrimSpace(f.TotpCode) == "" {
			return nil, status.Error(codes.InvalidArgument, "totp code is required")
		}
		if !totp.Validate(f.TotpCode, user.TotpSecret.String) {
			return nil, status.Error(codes.InvalidArgument, "invalid totp code")
		}
	case mfaFactorEmailOTP:
		f, ok := req.Factor.(*authv1.VerifyLoginMFARequest_EmailOtpCode)
		if !ok || strings.TrimSpace(f.EmailOtpCode) == "" {
			return nil, status.Error(codes.InvalidArgument, "email otp code is required")
		}
		if err := s.verifyMFAOTP(ctx, req.GetMfaSessionId(), mfaFactorEmailOTP, f.EmailOtpCode); err != nil {
			return nil, err
		}
	case mfaFactorPhoneOTP:
		f, ok := req.Factor.(*authv1.VerifyLoginMFARequest_PhoneOtpCode)
		if !ok || strings.TrimSpace(f.PhoneOtpCode) == "" {
			return nil, status.Error(codes.InvalidArgument, "phone otp code is required")
		}
		if err := s.verifyMFAOTP(ctx, req.GetMfaSessionId(), mfaFactorPhoneOTP, f.PhoneOtpCode); err != nil {
			return nil, err
		}
	case mfaFactorWebAuthn:
		f, ok := req.Factor.(*authv1.VerifyLoginMFARequest_WebauthnAssertion)
		if !ok || len(f.WebauthnAssertion) == 0 {
			return nil, status.Error(codes.InvalidArgument, "webauthn assertion is required")
		}
		return s.FinishWebAuthnLogin(ctx, &authv1.WebAuthnFinishLoginRequest{
			MfaSessionId: req.GetMfaSessionId(),
			Assertion:    f.WebauthnAssertion,
			DeviceId:     req.GetDeviceId(),
		})
	default:
		return nil, status.Error(codes.InvalidArgument, "unsupported mfa factor")
	}

	if err := s.redis.Del(ctx, fmt.Sprintf("mfa_challenge:%s", req.GetMfaSessionId())).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to clear mfa challenge")
	}
	if session.Flow == mfaFlowReopen {
		if err := s.validateReopenAndRevoke(ctx, session, req.GetDeviceId()); err != nil {
			return nil, err
		}
	}
	if err := s.redis.Del(ctx, fmt.Sprintf("mfa_session:%s", req.GetMfaSessionId())).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to clear mfa session")
	}

	return s.mintTokens(ctx, userID, string(user.Role), req.GetDeviceId())
}

// ChangePassword verifies current_password, validates new_password strength, and updates password hash.
// The password-change-required flag is always reset to false on successful update.
func (s *service) ChangePassword(ctx context.Context, req *authv1.ChangePasswordRequest) (*authv1.ChangePasswordResponse, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	currentPassword := strings.TrimSpace(req.GetCurrentPassword())
	newPassword := req.GetNewPassword()
	if currentPassword == "" || newPassword == "" {
		return nil, status.Error(codes.InvalidArgument, "current_password and new_password are required")
	}

	if err := util.ValidatePasswordStrength(newPassword); err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	match, err := argon2.VerifyPassword(currentPassword, user.PasswordHash)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to verify current password")
	}
	if !match {
		return nil, status.Error(codes.Unauthenticated, "current password is incorrect")
	}

	if ok, _ := argon2.VerifyPassword(newPassword, user.PasswordHash); ok {
		return nil, status.Error(codes.InvalidArgument, "new password must be different from current password")
	}

	hash, err := argon2.HashPassword(newPassword, argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash new password")
	}

	err = s.queries.ChangeUserPassword(ctx, generated.ChangeUserPasswordParams{
		ID:           pgtype.UUID{Bytes: userID, Valid: true},
		PasswordHash: hash,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update password")
	}

	return &authv1.ChangePasswordResponse{Success: true}, nil
}

func (s *service) InitiateForgotPassword(ctx context.Context, req *authv1.InitiateForgotPasswordRequest) (*authv1.InitiateForgotPasswordResponse, error) {
	identifier := strings.TrimSpace(req.GetEmailOrPhone())
	if identifier == "" {
		return nil, status.Error(codes.InvalidArgument, "email_or_phone is required")
	}

	user, err := s.queries.GetUserByEmailOrPhone(ctx, identifier)
	if err != nil {
		// Return success without revealing whether user exists
		return &authv1.InitiateForgotPasswordResponse{
			ChallengeSent: false,
		}, nil
	}

	emailOTP := "123456"
	phoneOTP := "123456"
	sessionID := uuid.NewString()

	session := forgotPasswordSession{
		UserID:      user.ID.String(),
		Email:       user.Email,
		Phone:       user.Phone,
		EmailOTP:    emailOTP,
		PhoneOTP:    phoneOTP,
		IsVerified:  false,
		AttemptLeft: 5,
	}

	b, err := json.Marshal(session)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to encode reset session")
	}

	if err := s.redis.Set(ctx, fmt.Sprintf("forgot_pwd:%s", sessionID), b, 10*time.Minute).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to store reset session")
	}

	fmt.Printf("DEBUG: Forgot password email OTP for %s: %s\n", user.Email, emailOTP)
	fmt.Printf("DEBUG: Forgot password phone OTP for %s: %s\n", user.Phone, phoneOTP)

	return &authv1.InitiateForgotPasswordResponse{
		ResetSessionId: sessionID,
		ChallengeSent:  true,
		MaskedEmail:    maskEmail(user.Email),
		MaskedPhone:    maskPhone(user.Phone),
	}, nil
}

func (s *service) VerifyForgotPasswordOTPs(ctx context.Context, req *authv1.VerifyForgotPasswordOTPsRequest) (*authv1.VerifyForgotPasswordOTPsResponse, error) {
	sessionID := strings.TrimSpace(req.GetResetSessionId())
	if sessionID == "" {
		return nil, status.Error(codes.InvalidArgument, "reset_session_id is required")
	}

	key := fmt.Sprintf("forgot_pwd:%s", sessionID)
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, status.Error(codes.NotFound, "reset session expired or invalid")
		}
		return nil, status.Error(codes.Internal, "failed to load reset session")
	}

	var session forgotPasswordSession
	if err := json.Unmarshal([]byte(val), &session); err != nil {
		return nil, status.Error(codes.Internal, "corrupt reset session")
	}

	if strings.TrimSpace(req.GetEmailCode()) != session.EmailOTP || strings.TrimSpace(req.GetPhoneCode()) != session.PhoneOTP {
		session.AttemptLeft--
		if session.AttemptLeft <= 0 {
			_ = s.redis.Del(ctx, key).Err()
			return nil, status.Error(codes.PermissionDenied, "too many invalid otp attempts")
		}
		updated, _ := json.Marshal(session)
		_ = s.redis.Set(ctx, key, updated, 10*time.Minute).Err()
		return nil, status.Error(codes.InvalidArgument, "invalid verification codes")
	}

	session.IsVerified = true
	updated, err := json.Marshal(session)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to encode reset session")
	}
	if err := s.redis.Set(ctx, key, updated, 10*time.Minute).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to persist reset session")
	}

	return &authv1.VerifyForgotPasswordOTPsResponse{Verified: true}, nil
}

func (s *service) ResetForgotPassword(ctx context.Context, req *authv1.ResetForgotPasswordRequest) (*authv1.ResetForgotPasswordResponse, error) {
	sessionID := strings.TrimSpace(req.GetResetSessionId())
	newPassword := req.GetNewPassword()
	if sessionID == "" || strings.TrimSpace(newPassword) == "" {
		return nil, status.Error(codes.InvalidArgument, "reset_session_id and new_password are required")
	}

	if err := util.ValidatePasswordStrength(newPassword); err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	key := fmt.Sprintf("forgot_pwd:%s", sessionID)
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, status.Error(codes.NotFound, "reset session expired or invalid")
		}
		return nil, status.Error(codes.Internal, "failed to load reset session")
	}

	var session forgotPasswordSession
	if err := json.Unmarshal([]byte(val), &session); err != nil {
		return nil, status.Error(codes.Internal, "corrupt reset session")
	}
	if !session.IsVerified {
		return nil, status.Error(codes.FailedPrecondition, "otps are not verified")
	}

	userID, err := uuid.Parse(session.UserID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid reset user")
	}

	hash, err := argon2.HashPassword(newPassword, argon2.DefaultConfig())
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to hash password")
	}

	if err := s.queries.ResetUserPassword(ctx, generated.ResetUserPasswordParams{
		ID:           pgtype.UUID{Bytes: userID, Valid: true},
		PasswordHash: hash,
	}); err != nil {
		return nil, status.Error(codes.Internal, "failed to reset password")
	}

	_ = s.redis.Del(ctx, key).Err()

	return &authv1.ResetForgotPasswordResponse{Success: true}, nil
}

func (s *service) GetMyProfile(ctx context.Context, req *authv1.GetMyProfileRequest) (*authv1.GetMyProfileResponse, error) {
	_ = req

	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	response := &authv1.GetMyProfileResponse{
		UserId:                    user.ID.String(),
		Email:                     user.Email,
		Phone:                     user.Phone,
		Role:                      mapDBRoleToProto(user.Role),
		IsEmailVerified:           user.IsEmailVerified.Bool,
		IsPhoneVerified:           user.IsPhoneVerified.Bool,
		IsActive:                  user.IsActive.Bool,
		IsRequiringPasswordChange: user.IsRequiringPasswordChange.Bool,
		HasTotp:                   user.HasTotp.Bool,
		CreatedAt:                 timeToString(user.CreatedAt),
	}

	switch user.Role {
	case generated.UserRoleAdmin:
		profile, err := s.queries.GetAdminProfileByUserID(ctx, user.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.Internal, "failed to load admin profile")
		}
		if err == nil {
			response.Profile = &authv1.GetMyProfileResponse_AdminProfile{AdminProfile: &authv1.AdminProfile{
				ProfileId: profile.ID.String(),
				CreatedAt: timeToString(profile.CreatedAt),
			}}
		}
	case generated.UserRoleManager:
		profile, err := s.queries.GetManagerProfileByUserID(ctx, user.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.Internal, "failed to load manager profile")
		}
		if err == nil {
			response.Profile = &authv1.GetMyProfileResponse_ManagerProfile{ManagerProfile: &authv1.ManagerProfile{
				ProfileId:      profile.ID.String(),
				Name:           profile.Name,
				Branch:         s.loadBranchProfile(ctx, profile.BranchID),
				CreatedAt:      timeToString(profile.CreatedAt),
				EmployeeSerial: profile.EmployeeSerial,
				EmployeeCode:   nullableTextToString(profile.EmployeeCode),
			}}
		}
	case generated.UserRoleOfficer:
		profile, err := s.queries.GetOfficerProfileByUserID(ctx, user.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.Internal, "failed to load officer profile")
		}
		if err == nil {
			response.Profile = &authv1.GetMyProfileResponse_OfficerProfile{OfficerProfile: &authv1.OfficerProfile{
				ProfileId:      profile.ID.String(),
				Name:           profile.Name,
				Branch:         s.loadBranchProfile(ctx, profile.BranchID),
				CreatedAt:      timeToString(profile.CreatedAt),
				EmployeeSerial: profile.EmployeeSerial,
				EmployeeCode:   nullableTextToString(profile.EmployeeCode),
			}}
		}
	case generated.UserRoleBorrower:
		profile, err := s.queries.GetBorrowerProfileByUserID(ctx, user.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.Internal, "failed to load borrower profile")
		}
		if err == nil {
			response.Profile = &authv1.GetMyProfileResponse_BorrowerProfile{BorrowerProfile: &authv1.BorrowerProfile{
				ProfileId:                  profile.ID.String(),
				FirstName:                  profile.FirstName,
				LastName:                   profile.LastName,
				DateOfBirth:                dateToString(profile.DateOfBirth),
				Gender:                     string(profile.Gender),
				AddressLine1:               profile.AddressLine1,
				City:                       profile.City,
				State:                      profile.State,
				Pincode:                    profile.Pincode,
				EmploymentType:             string(profile.EmploymentType),
				MonthlyIncome:              numericToString(profile.MonthlyIncome),
				ProfileCompletenessPercent: profile.ProfileCompletenessPercent,
				IsAadhaarVerified:          profile.IsAadhaarVerified,
				IsPanVerified:              profile.IsPanVerified,
				AadhaarVerifiedAt:          timeToString(profile.AadhaarVerifiedAt),
				PanVerifiedAt:              timeToString(profile.PanVerifiedAt),
				CreatedAt:                  timeToString(profile.CreatedAt),
				CibilScore:                 profile.CibilScore,
			}}
		}
	case generated.UserRoleDst:
		profile, err := s.queries.GetDstProfileByUserID(ctx, user.ID)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.Internal, "failed to load dst profile")
		}
		if err == nil {
			response.Profile = &authv1.GetMyProfileResponse_DstProfile{DstProfile: &authv1.DstProfile{
				ProfileId: profile.ID.String(),
				Name:      profile.Name,
				Branch:    s.loadBranchProfile(ctx, profile.BranchID),
				CreatedAt: timeToString(profile.CreatedAt),
			}}
		}
	}

	return response, nil
}

func (s *service) GetBorrowerProfile(ctx context.Context, req *authv1.GetBorrowerProfileRequest) (*authv1.BorrowerProfile, error) {
	callerUserID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)

	targetUserIDStr := strings.TrimSpace(req.GetUserID())
	if targetUserIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}
	targetUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "user_id must be a valid uuid")
	}

	switch role {
	case "borrower":
		if targetUserID != callerUserID {
			return nil, status.Error(codes.PermissionDenied, "borrower can only view own profile")
		}
	case "officer", "manager", "admin", "dst":
	default:
		return nil, status.Error(codes.PermissionDenied, "access denied")
	}

	profile, err := s.queries.GetBorrowerProfileByUserID(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "borrower profile not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch profile")
	}

	result := &authv1.BorrowerProfile{
		ProfileId:                  profile.ID.String(),
		FirstName:                  profile.FirstName,
		LastName:                   profile.LastName,
		DateOfBirth:                dateToString(profile.DateOfBirth),
		Gender:                     string(profile.Gender),
		AddressLine1:               profile.AddressLine1,
		City:                       profile.City,
		State:                      profile.State,
		Pincode:                    profile.Pincode,
		EmploymentType:             string(profile.EmploymentType),
		MonthlyIncome:              numericToString(profile.MonthlyIncome),
		ProfileCompletenessPercent: profile.ProfileCompletenessPercent,
		IsAadhaarVerified:          profile.IsAadhaarVerified,
		IsPanVerified:              profile.IsPanVerified,
		AadhaarVerifiedAt:          timeToString(profile.AadhaarVerifiedAt),
		PanVerifiedAt:              timeToString(profile.PanVerifiedAt),
		CreatedAt:                  timeToString(profile.CreatedAt),
		CibilScore:                 profile.CibilScore,
	}

	return result, nil
}

func (s *service) GetUser(ctx context.Context, req *authv1.GetUserRequest) (*authv1.GetUserResponse, error) {
	targetUserIDStr := strings.TrimSpace(req.GetUserId())
	if targetUserIDStr == "" {
		return nil, status.Error(codes.InvalidArgument, "user_id is required")
	}
	targetUserID, err := uuid.Parse(targetUserIDStr)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "user_id must be a valid uuid")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: targetUserID, Valid: true})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Error(codes.Internal, "failed to fetch user")
	}

	return &authv1.GetUserResponse{
		User: &authv1.UserPublicProfile{
			UserId:    user.ID.String(),
			Email:     user.Email,
			Phone:     user.Phone,
			Role:      mapDBRoleToProto(user.Role),
			IsActive:  user.IsActive.Bool,
			CreatedAt: timeToString(user.CreatedAt),
		},
	}, nil
}

func (s *service) SearchBorrowerSignupStatus(ctx context.Context, req *authv1.SearchBorrowerSignupStatusRequest) (*authv1.SearchBorrowerSignupStatusResponse, error) {
	_, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	if role != "officer" && role != "dst" && role != "manager" && role != "admin" {
		return nil, status.Error(codes.PermissionDenied, "role cannot search borrowers")
	}
	query := strings.TrimSpace(req.GetQuery())
	if query == "" {
		return nil, status.Error(codes.InvalidArgument, "query is required")
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
	rows, err := s.queries.SearchBorrowerSignupStatus(ctx, generated.SearchBorrowerSignupStatusParams{
		Column1: pgtype.Text{String: query, Valid: true},
		Limit:   limit,
		Offset:  offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to search borrower status")
	}
	items := make([]*authv1.BorrowerSignupStatusItem, 0, len(rows))
	for _, row := range rows {
		onboardingDone := row.BorrowerProfileID.Valid
		kycDone := row.IsAadhaarVerified && row.IsPanVerified
		stage := "ACCOUNT_CREATED"
		switch {
		case onboardingDone && kycDone:
			stage = "KYC_DONE"
		case onboardingDone:
			stage = "ONBOARDING_DONE"
		case row.IsEmailVerified.Bool && row.IsPhoneVerified.Bool:
			stage = "OTP_VERIFIED"
		}
		items = append(items, &authv1.BorrowerSignupStatusItem{
			UserId:              row.UserID.String(),
			Email:               row.Email,
			Phone:               row.Phone,
			IsEmailVerified:     row.IsEmailVerified.Bool,
			IsPhoneVerified:     row.IsPhoneVerified.Bool,
			IsActive:            row.IsActive.Bool,
			OnboardingCompleted: onboardingDone,
			KycCompleted:        kycDone,
			BorrowerProfileId:   nullableUUIDToString(row.BorrowerProfileID),
			SignupStage:         stage,
		})
	}
	return &authv1.SearchBorrowerSignupStatusResponse{Items: items}, nil
}

func (s *service) loadBranchProfile(ctx context.Context, branchID pgtype.UUID) *authv1.BranchProfile {
	if !branchID.Valid {
		return nil
	}

	branch, err := s.queries.GetBankBranchByID(ctx, branchID)
	if err != nil {
		return nil
	}

	return &authv1.BranchProfile{
		BranchId:      branch.ID.String(),
		Name:          branch.Name,
		Region:        branch.Region,
		City:          branch.City,
		DstCommission: numericToString(branch.DstCommission),
	}
}

// getMFASession loads and validates the MFA session blob from Redis.
func (s *service) getMFASession(ctx context.Context, sessionID string) (*mfaSessionState, error) {
	key := fmt.Sprintf("mfa_session:%s", sessionID)
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return nil, status.Error(codes.Unauthenticated, "mfa session expired or invalid")
		}
		return nil, status.Error(codes.Internal, "failed to load mfa session")
	}

	var session mfaSessionState
	if err := json.Unmarshal([]byte(val), &session); err != nil {
		return nil, status.Error(codes.Internal, "corrupt mfa session")
	}

	if session.UserID == "" {
		return nil, status.Error(codes.Internal, "invalid mfa session")
	}

	return &session, nil
}

// setMFASession persists MFA session state with a fresh TTL.
func (s *service) setMFASession(ctx context.Context, sessionID string, session *mfaSessionState) error {
	b, err := json.Marshal(session)
	if err != nil {
		return status.Error(codes.Internal, "failed to encode mfa session")
	}

	if err := s.redis.Set(ctx, fmt.Sprintf("mfa_session:%s", sessionID), b, mfaSessionTTL).Err(); err != nil {
		return status.Error(codes.Internal, "failed to persist mfa session")
	}

	return nil
}

// verifyMFAOTP compares OTP challenge hash, updates attempt counters, and enforces max attempts.
func (s *service) verifyMFAOTP(ctx context.Context, sessionID, factor, code string) error {
	key := fmt.Sprintf("mfa_challenge:%s", sessionID)
	val, err := s.redis.Get(ctx, key).Result()
	if err != nil {
		if err == redis.Nil {
			return status.Error(codes.Unauthenticated, "mfa challenge expired or missing")
		}
		return status.Error(codes.Internal, "failed to load mfa challenge")
	}

	var challenge mfaOTPChallenge
	if err := json.Unmarshal([]byte(val), &challenge); err != nil {
		return status.Error(codes.Internal, "corrupt mfa challenge")
	}

	if challenge.Factor != factor {
		return status.Error(codes.InvalidArgument, "mfa factor mismatch")
	}

	if challenge.MaxTry <= 0 {
		challenge.MaxTry = mfaChallengeMaxTry
	}

	if subtle.ConstantTimeCompare([]byte(hashOTP(code)), []byte(challenge.OTPHash)) != 1 {
		challenge.Attempts++
		if challenge.Attempts >= challenge.MaxTry {
			_ = s.redis.Del(ctx, key).Err()
			_ = s.redis.Del(ctx, fmt.Sprintf("mfa_session:%s", sessionID)).Err()
			return status.Error(codes.PermissionDenied, "too many invalid mfa attempts")
		}

		challengeJSON, err := json.Marshal(challenge)
		if err != nil {
			return status.Error(codes.Internal, "failed to encode mfa challenge")
		}

		if err := s.redis.Set(ctx, key, challengeJSON, mfaChallengeTTL).Err(); err != nil {
			return status.Error(codes.Internal, "failed to persist mfa challenge")
		}

		return status.Error(codes.InvalidArgument, "invalid otp code")
	}

	return nil
}

// RefreshToken rotates refresh tokens and mints a fresh access/refresh pair.
func (s *service) RefreshToken(ctx context.Context, req *authv1.RefreshTokenRequest) (*authv1.AuthTokens, error) {
	_ = ctx
	_ = req
	return nil, status.Error(codes.FailedPrecondition, "direct refresh is disabled; use InitiateReopen and complete MFA")
}

// Logout revokes refresh token and clears the active access-token session in Redis.
func (s *service) Logout(ctx context.Context, req *authv1.LogoutRequest) (*authv1.LogoutResponse, error) {
	// 1. Revoke refresh token
	hash := sha256.Sum256([]byte(req.GetRefreshToken()))
	hashedToken := hex.EncodeToString(hash[:])
	if err := s.queries.RevokeRefreshToken(ctx, hashedToken); err != nil {
		return nil, status.Error(codes.Internal, "failed to revoke refresh token")
	}

	// 2. Denylist access token (JTI) in Redis (Instruction 6)
	// First parse access token claims to get JTI and UserID
	token, err := jwt.ParseWithClaims(req.GetAccessToken(), &interceptors.AuthClaims{}, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, status.Error(codes.Unauthenticated, "unexpected signing method")
		}
		return []byte(s.cfg.JWTKey), nil
	})
	if err == nil && token.Valid {
		if claims, ok := token.Claims.(*interceptors.AuthClaims); ok && claims.Subject != "" {
			if err := s.redis.Del(ctx, fmt.Sprintf("active_token:%s", claims.Subject)).Err(); err != nil {
				return nil, status.Error(codes.Internal, "failed to clear active session")
			}
		}
	}

	return &authv1.LogoutResponse{Success: true}, nil
}

// --- WebAuthn Adapter ---

type webauthnUser struct {
	id          []byte
	email       string
	credentials []webauthn.Credential
}

func (u *webauthnUser) WebAuthnID() []byte                         { return u.id }
func (u *webauthnUser) WebAuthnName() string                       { return u.email }
func (u *webauthnUser) WebAuthnDisplayName() string                { return u.email }
func (u *webauthnUser) WebAuthnIcon() string                       { return "" }
func (u *webauthnUser) WebAuthnCredentials() []webauthn.Credential { return u.credentials }

func (s *service) getWebauthnUser(ctx context.Context, user generated.User) (*webauthnUser, error) {
	dbCreds, err := s.queries.GetWebAuthnCredentialsByUserID(ctx, user.ID)
	if err != nil {
		return nil, err
	}

	creds := make([]webauthn.Credential, len(dbCreds))
	for i, c := range dbCreds {
		creds[i] = webauthn.Credential{
			ID:              c.CredentialID,
			PublicKey:       c.PublicKey,
			AttestationType: "none",
			Authenticator: webauthn.Authenticator{
				SignCount: uint32(c.SignCount.Int32),
			},
		}
	}

	return &webauthnUser{
		id:          user.ID.Bytes[:],
		email:       user.Email,
		credentials: creds,
	}, nil
}

func (s *service) BeginWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnRegRequest) (*authv1.WebAuthnRegResponse, error) {
	_ = req
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	userIDStr := userID.String()

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "user fetch failed")
	}

	waUser, err := s.getWebauthnUser(ctx, user)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to build webauthn user")
	}

	options, session, err := s.webauthn.BeginRegistration(waUser)
	if err != nil {
		return nil, status.Error(codes.Internal, "webauthn begin failed")
	}

	sessJSON, err := json.Marshal(session)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize registration session")
	}
	if err := s.redis.Set(ctx, fmt.Sprintf("webauthn_reg:%s", userIDStr), sessJSON, 5*time.Minute).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to persist registration session")
	}

	optionsJSON, err := json.Marshal(options.Response)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize registration options")
	}
	return &authv1.WebAuthnRegResponse{
		PublicKeyCredentialCreationOptions: optionsJSON,
	}, nil
}

func (s *service) FinishWebAuthnRegistration(ctx context.Context, req *authv1.WebAuthnFinishRegRequest) (*authv1.AuthTokens, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing user context")
	}
	userIDStr := userID.String()

	if strings.TrimSpace(req.GetUserId()) != "" && req.GetUserId() != userIDStr {
		return nil, status.Error(codes.PermissionDenied, "user mismatch")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "user fetch failed")
	}

	sessVal, err := s.redis.Get(ctx, fmt.Sprintf("webauthn_reg:%s", userIDStr)).Result()
	if err != nil {
		return nil, status.Error(codes.FailedPrecondition, "registration session expired")
	}

	var session webauthn.SessionData
	if err := json.Unmarshal([]byte(sessVal), &session); err != nil {
		return nil, status.Error(codes.Internal, "invalid registration session")
	}

	parsedCredential, err := protocol.ParseCredentialCreationResponseBytes(req.GetCredential())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid credential payload")
	}

	waUser, err := s.getWebauthnUser(ctx, user)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to build webauthn user")
	}

	credential, err := s.webauthn.CreateCredential(waUser, session, parsedCredential)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "webauthn registration validation failed")
	}

	_, err = s.queries.CreateWebAuthnCredential(ctx, generated.CreateWebAuthnCredentialParams{
		UserID:       pgtype.UUID{Bytes: userID, Valid: true},
		CredentialID: credential.ID,
		PublicKey:    credential.PublicKey,
		SignCount:    pgtype.Int4{Int32: int32(credential.Authenticator.SignCount), Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to store passkey credential")
	}

	if err := s.redis.Del(ctx, fmt.Sprintf("webauthn_reg:%s", userIDStr)).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to clear registration session")
	}

	return s.mintTokens(ctx, userID, string(user.Role), req.GetDeviceId())

}

func (s *service) BeginWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnLoginRequest) (*authv1.WebAuthnLoginResponse, error) {
	userUUID, err := uuid.Parse(req.GetUserId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user id")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userUUID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	waUser, err := s.getWebauthnUser(ctx, user)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to build webauthn user")
	}
	options, session, err := s.webauthn.BeginLogin(waUser)
	if err != nil {
		return nil, status.Error(codes.Internal, "webauthn login begin failed")
	}

	mfaSessionID := uuid.New().String()
	loginSession := webauthnLoginSession{
		UserID:  user.ID.String(),
		Session: *session,
	}
	sessJSON, err := json.Marshal(loginSession)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize login session")
	}
	if err := s.redis.Set(ctx, fmt.Sprintf("webauthn_login:%s", mfaSessionID), sessJSON, 5*time.Minute).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to persist login session")
	}

	optionsJSON, err := json.Marshal(options.Response)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to serialize login options")
	}
	return &authv1.WebAuthnLoginResponse{
		MfaSessionId:                      mfaSessionID,
		PublicKeyCredentialRequestOptions: optionsJSON,
	}, nil
}

func (s *service) FinishWebAuthnLogin(ctx context.Context, req *authv1.WebAuthnFinishLoginRequest) (*authv1.AuthTokens, error) {
	sessVal, err := s.redis.Get(ctx, fmt.Sprintf("webauthn_login:%s", req.GetMfaSessionId())).Result()
	if err != nil {
		return nil, status.Error(codes.FailedPrecondition, "login session expired")
	}

	var loginSession webauthnLoginSession
	if err := json.Unmarshal([]byte(sessVal), &loginSession); err != nil {
		return nil, status.Error(codes.Internal, "invalid login session")
	}

	userID, err := uuid.Parse(loginSession.UserID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid login user id")
	}

	user, err := s.queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	waUser, err := s.getWebauthnUser(ctx, user)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to build webauthn user")
	}

	parsedAssertion, err := protocol.ParseCredentialRequestResponseBytes(req.GetAssertion())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid assertion payload")
	}

	credential, err := s.webauthn.ValidateLogin(waUser, loginSession.Session, parsedAssertion)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "webauthn login validation failed")
	}

	mfaSession, err := s.getMFASession(ctx, req.GetMfaSessionId())
	if err == nil && mfaSession.Flow == mfaFlowReopen {
		if err := s.validateReopenAndRevoke(ctx, mfaSession, req.GetDeviceId()); err != nil {
			return nil, err
		}
	}

	err = s.queries.UpdateWebAuthnCredentialSignCount(ctx, generated.UpdateWebAuthnCredentialSignCountParams{
		CredentialID: credential.ID,
		SignCount:    pgtype.Int4{Int32: int32(credential.Authenticator.SignCount), Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update credential sign count")
	}

	if err := s.redis.Del(ctx, fmt.Sprintf("webauthn_login:%s", req.GetMfaSessionId())).Err(); err != nil {
		return nil, status.Error(codes.Internal, "failed to clear login session")
	}
	_ = s.redis.Del(ctx, fmt.Sprintf("mfa_session:%s", req.GetMfaSessionId())).Err()
	_ = s.redis.Del(ctx, fmt.Sprintf("mfa_challenge:%s", req.GetMfaSessionId())).Err()

	return s.mintTokens(ctx, userID, string(user.Role), req.GetDeviceId())
}

func (s *service) loadAllowedFactors(ctx context.Context, user generated.User) ([]string, error) {
	allowedFactors := []string{}
	if user.HasTotp.Bool {
		allowedFactors = append(allowedFactors, mfaFactorTOTP)
	}
	if user.IsEmailVerified.Bool {
		allowedFactors = append(allowedFactors, mfaFactorEmailOTP)
	}
	if user.IsPhoneVerified.Bool {
		allowedFactors = append(allowedFactors, mfaFactorPhoneOTP)
	}

	webauthnCreds, err := s.queries.GetWebAuthnCredentialsByUserID(ctx, user.ID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to load passkey credentials")
	}
	if len(webauthnCreds) > 0 {
		allowedFactors = append(allowedFactors, mfaFactorWebAuthn)
	}

	return allowedFactors, nil
}

func (s *service) validateReopenAndRevoke(ctx context.Context, session *mfaSessionState, deviceID string) error {
	if session == nil || session.Flow != mfaFlowReopen {
		return nil
	}
	if strings.TrimSpace(session.RefreshHash) == "" {
		return status.Error(codes.FailedPrecondition, "invalid reopen session")
	}
	if strings.TrimSpace(deviceID) == "" {
		return status.Error(codes.InvalidArgument, "device_id is required")
	}
	if session.BoundDeviceID != "" && session.BoundDeviceID != deviceID {
		return status.Error(codes.Unauthenticated, "invalid device id")
	}

	tokenRecord, err := s.queries.GetRefreshTokenByHashedTokenAny(ctx, session.RefreshHash)
	if err != nil {
		return status.Error(codes.Unauthenticated, "session expired; password login required")
	}
	if tokenRecord.IsRevoked.Bool {
		return status.Error(codes.Unauthenticated, "session logged out; password login required")
	}
	if isRefreshTokenExpired(tokenRecord.ExpiresAt) {
		return status.Error(codes.Unauthenticated, "session expired; password login required")
	}
	if tokenRecord.DeviceID != deviceID {
		return status.Error(codes.Unauthenticated, "invalid device id")
	}

	if err := s.queries.RevokeRefreshToken(ctx, session.RefreshHash); err != nil {
		return status.Error(codes.Internal, "failed to rotate previous refresh token")
	}

	return nil
}

func (s *service) mintTokens(ctx context.Context, userID uuid.UUID, role, deviceID string) (*authv1.AuthTokens, error) {
	pair, err := util.MintTokens(ctx, s.queries, s.redis, s.cfg.JWTKey, userID, role, deviceID)
	if err != nil {
		return nil, err
	}
	return &authv1.AuthTokens{
		AccessToken:  pair.AccessToken,
		RefreshToken: pair.RefreshToken,
	}, nil
}

func generateOTP() string {
	max := big.NewInt(1000000)
	n, _ := rand.Int(rand.Reader, max)
	return fmt.Sprintf("%06d", n)
}

func containsString(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func hashOTP(code string) string {
	h := sha256.Sum256([]byte(code))
	return hex.EncodeToString(h[:])
}

func hashRefreshToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

func isRefreshTokenExpired(expiresAt pgtype.Timestamptz) bool {
	if !expiresAt.Valid {
		return true
	}
	return !expiresAt.Time.After(time.Now())
}

func maskEmail(email string) string {
	parts := strings.SplitN(email, "@", 2)
	if len(parts) != 2 {
		return ""
	}
	local := parts[0]
	if len(local) <= 2 {
		return "**@" + parts[1]
	}
	return local[:2] + "***@" + parts[1]
}

func maskPhone(phone string) string {
	if len(phone) <= 4 {
		return "****"
	}
	return "***" + phone[len(phone)-4:]
}

func mapProtoRole(role authv1.UserRole) (generated.UserRole, error) {
	switch role {
	case authv1.UserRole_USER_ROLE_ADMIN:
		return generated.UserRoleAdmin, nil
	case authv1.UserRole_USER_ROLE_MANAGER:
		return generated.UserRoleManager, nil
	case authv1.UserRole_USER_ROLE_OFFICER:
		return generated.UserRoleOfficer, nil
	case authv1.UserRole_USER_ROLE_BORROWER:
		return generated.UserRoleBorrower, nil
	case authv1.UserRole_USER_ROLE_DST:
		return generated.UserRoleDst, nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid role")
	}
}

func mapDBRoleToProto(role generated.UserRole) authv1.UserRole {
	switch role {
	case generated.UserRoleAdmin:
		return authv1.UserRole_USER_ROLE_ADMIN
	case generated.UserRoleManager:
		return authv1.UserRole_USER_ROLE_MANAGER
	case generated.UserRoleOfficer:
		return authv1.UserRole_USER_ROLE_OFFICER
	case generated.UserRoleBorrower:
		return authv1.UserRole_USER_ROLE_BORROWER
	case generated.UserRoleDst:
		return authv1.UserRole_USER_ROLE_DST
	default:
		return authv1.UserRole_USER_ROLE_UNSPECIFIED
	}
}

func dateToString(d pgtype.Date) string {
	if !d.Valid {
		return ""
	}
	return d.Time.UTC().Format("2006-01-02")
}

func timeToString(t pgtype.Timestamptz) string {
	if !t.Valid {
		return ""
	}
	return t.Time.UTC().Format(time.RFC3339)
}

func numericToString(n pgtype.Numeric) string {
	if !n.Valid {
		return ""
	}
	b, err := n.MarshalJSON()
	if err == nil {
		s := strings.Trim(string(b), "\"")
		if s != "" && s != "null" {
			return s
		}
	}
	v, err := n.Float64Value()
	if err != nil || !v.Valid {
		return ""
	}
	return strconv.FormatFloat(v.Float64, 'f', -1, 64)
}

func nullableTextToString(t pgtype.Text) string {
	if !t.Valid {
		return ""
	}
	return t.String
}

func nullableUUIDToString(v pgtype.UUID) string {
	if !v.Valid {
		return ""
	}
	return uuid.UUID(v.Bytes).String()
}
