package interceptors

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type contextKey string

const (
	ContextUserIDKey   contextKey = "user_id"
	ContextRoleKey     contextKey = "role"
	ContextIdentityKey contextKey = "identity"
)

type Identity struct {
	UserID uuid.UUID
	Role   string
}

type RBACPolicy map[string][]string

// RBACUnaryInterceptor enforces role-based access for methods defined in policy.
// Methods that are not present in the policy map are allowed to continue.
func RBACUnaryInterceptor(policy RBACPolicy) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		allowedRoles, ok := policy[info.FullMethod]
		if !ok {
			// If method not in policy, we assume it's publicly accessible or handled by JWT interceptor
			return handler(ctx, req)
		}

		userRole, ok := ctx.Value(ContextRoleKey).(string)
		if !ok || userRole == "" {
			return nil, status.Error(codes.Unauthenticated, "missing user role")
		}

		for _, role := range allowedRoles {
			if role == userRole {
				return handler(ctx, req)
			}
		}

		return nil, status.Error(codes.PermissionDenied, "access denied for this role")
	}
}

type AuthClaims struct {
	Role                      string `json:"role"`
	IsRequiringPasswordChange bool   `json:"is_requiring_password_change"`
	IsActive                  bool   `json:"is_active"`
	jwt.RegisteredClaims
}

type JWTConfig struct {
	SigningKey    []byte
	RedisClient   redis.Cmdable
	PublicMethods map[string]struct{}
}

// JWTUnaryInterceptor validates bearer JWTs and verifies active session state in Redis.
// For non-public methods, it injects authenticated user ID and role into context.
// It also enforces password change and active state requirements.
func JWTUnaryInterceptor(cfg JWTConfig) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		_ = req

		if _, ok := cfg.PublicMethods[info.FullMethod]; ok {
			return handler(ctx, req)
		}

		token, err := extractBearerToken(ctx)
		if err != nil {
			return nil, status.Error(codes.Unauthenticated, err.Error())
		}

		claims, err := parseAndValidateJWT(token, cfg.SigningKey)
		if err != nil {
			return nil, status.Error(codes.Unauthenticated, "invalid token")
		}

		if cfg.RedisClient == nil {
			return nil, status.Error(codes.Internal, "redis auth state unavailable")
		}

		key := fmt.Sprintf("active_token:%s", claims.Subject)
		activeJTI, err := cfg.RedisClient.Get(ctx, key).Result()
		if err != nil {
			if errors.Is(err, redis.Nil) {
				return nil, status.Error(codes.Unauthenticated, "session expired")
			}
			return nil, status.Error(codes.Internal, "failed auth state lookup")
		}

		if activeJTI != claims.ID {
			return nil, status.Error(codes.Unauthenticated, "token is no longer active")
		}

		// Enforce password change requirement
		if claims.IsRequiringPasswordChange {
			if info.FullMethod != "/auth.v1.AuthService/ChangePassword" && info.FullMethod != "/auth.v1.AuthService/Logout" && info.FullMethod != "/auth.v1.AuthService/GetMyProfile" {
				return nil, status.Error(codes.FailedPrecondition, "password change required")
			}
		}

// Enforce active profile requirement (onboarding)
	// Inactive users can only access auth self-service, onboarding, and KYC read endpoints.
	// Once CompleteBorrowerOnboarding succeeds, the user is activated and a fresh
	// token pair is returned — all subsequent calls use the new token with is_active=true.
	if !claims.IsActive {
		switch info.FullMethod {
		case "/auth.v1.AuthService/Logout",
			"/auth.v1.AuthService/GetMyProfile",
			"/auth.v1.AuthService/GetBorrowerProfile",
			"/onboarding.v1.OnboardingService/CompleteBorrowerOnboarding",
			"/onboarding.v1.OnboardingService/UpdateBorrowerProfile",
			"/auth.v1.AuthService/ChangePassword",
			"/auth.v1.AuthService/SetupTOTP",
			"/auth.v1.AuthService/VerifyTOTPSetup",
			"/kyc.v1.KycService/GetBorrowerKycStatus",
			"/kyc.v1.KycService/ListBorrowerKycHistory":
			// Allowed
		default:
			return nil, status.Error(codes.PermissionDenied, "user account is inactive. please complete onboarding.")
		}
	}

		userID, err := uuid.Parse(claims.Subject)
		if err != nil {
			return nil, status.Error(codes.Unauthenticated, "invalid subject claim")
		}

		ctx = context.WithValue(ctx, ContextUserIDKey, userID)
		ctx = context.WithValue(ctx, ContextRoleKey, claims.Role)

		if identity, ok := ctx.Value(ContextIdentityKey).(*Identity); ok {
			identity.UserID = userID
			identity.Role = claims.Role
		}

		return handler(ctx, req)
	}
}

// JWTStreamInterceptor validates bearer JWTs for server-streaming RPCs.
// It mirrors JWTUnaryInterceptor but uses grpc.StreamServerInterceptor.
func JWTStreamInterceptor(cfg JWTConfig) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		if _, ok := cfg.PublicMethods[info.FullMethod]; ok {
			return handler(srv, ss)
		}

		token, err := extractBearerToken(ss.Context())
		if err != nil {
			return status.Error(codes.Unauthenticated, err.Error())
		}

		claims, err := parseAndValidateJWT(token, cfg.SigningKey)
		if err != nil {
			return status.Error(codes.Unauthenticated, "invalid token")
		}

		if cfg.RedisClient == nil {
			return status.Error(codes.Internal, "redis auth state unavailable")
		}

		key := fmt.Sprintf("active_token:%s", claims.Subject)
		activeJTI, err := cfg.RedisClient.Get(ss.Context(), key).Result()
		if err != nil {
			if errors.Is(err, redis.Nil) {
				return status.Error(codes.Unauthenticated, "session expired")
			}
			return status.Error(codes.Internal, "failed auth state lookup")
		}

		if activeJTI != claims.ID {
			return status.Error(codes.Unauthenticated, "token is no longer active")
		}

		if claims.IsRequiringPasswordChange {
			if info.FullMethod != "/auth.v1.AuthService/ChangePassword" && info.FullMethod != "/auth.v1.AuthService/Logout" && info.FullMethod != "/auth.v1.AuthService/GetMyProfile" {
				return status.Error(codes.FailedPrecondition, "password change required")
			}
		}

		if !claims.IsActive {
			switch info.FullMethod {
			case "/auth.v1.AuthService/Logout",
				"/auth.v1.AuthService/GetMyProfile",
				"/auth.v1.AuthService/GetBorrowerProfile",
				"/onboarding.v1.OnboardingService/CompleteBorrowerOnboarding",
				"/onboarding.v1.OnboardingService/UpdateBorrowerProfile",
				"/auth.v1.AuthService/ChangePassword",
				"/auth.v1.AuthService/SetupTOTP",
				"/auth.v1.AuthService/VerifyTOTPSetup",
				"/kyc.v1.KycService/GetBorrowerKycStatus",
				"/kyc.v1.KycService/ListBorrowerKycHistory":
				// Allowed
			default:
				return status.Error(codes.PermissionDenied, "user account is inactive. please complete onboarding.")
			}
		}

		userID, err := uuid.Parse(claims.Subject)
		if err != nil {
			return status.Error(codes.Unauthenticated, "invalid subject claim")
		}

		ctx := context.WithValue(ss.Context(), ContextUserIDKey, userID)
		ctx = context.WithValue(ctx, ContextRoleKey, claims.Role)

		if identity, ok := ctx.Value(ContextIdentityKey).(*Identity); ok {
			identity.UserID = userID
			identity.Role = claims.Role
		}

		wrapped := &wrappedServerStream{ServerStream: ss, ctx: ctx}
		return handler(srv, wrapped)
	}
}

// wrappedServerStream wraps grpc.ServerStream to carry an overridden context.
type wrappedServerStream struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedServerStream) Context() context.Context { return w.ctx }

// RBACStreamInterceptor enforces role-based access for streaming RPCs.
func RBACStreamInterceptor(policy RBACPolicy) grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		allowedRoles, ok := policy[info.FullMethod]
		if !ok {
			return handler(srv, ss)
		}

		userRole, ok := ss.Context().Value(ContextRoleKey).(string)
		if !ok || userRole == "" {
			return status.Error(codes.Unauthenticated, "missing user role")
		}

		for _, role := range allowedRoles {
			if role == userRole {
				return handler(srv, ss)
			}
		}

		return status.Error(codes.PermissionDenied, "access denied for this role")
	}
}

// UserIDFromContext returns the authenticated user ID set by JWTUnaryInterceptor.
func UserIDFromContext(ctx context.Context) (uuid.UUID, bool) {
	userID, ok := ctx.Value(ContextUserIDKey).(uuid.UUID)
	if !ok {
		return uuid.UUID{}, false
	}
	return userID, true
}

func extractBearerToken(ctx context.Context) (string, error) {
	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return "", errors.New("missing metadata")
	}

	authHeaders := md.Get("authorization")
	if len(authHeaders) == 0 {
		return "", errors.New("missing authorization header")
	}

	header := strings.TrimSpace(authHeaders[0])
	if !strings.HasPrefix(strings.ToLower(header), "bearer ") {
		return "", errors.New("invalid authorization scheme")
	}

	token := strings.TrimSpace(header[len("Bearer "):])
	if token == "" {
		return "", errors.New("empty bearer token")
	}

	return token, nil
}

func parseAndValidateJWT(token string, key []byte) (*AuthClaims, error) {
	if len(key) == 0 {
		return nil, errors.New("empty jwt key")
	}

	claims := &AuthClaims{}
	parsedToken, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return key, nil
	})
	if err != nil || !parsedToken.Valid {
		return nil, errors.New("jwt parse failed")
	}

	if claims.Subject == "" || claims.ID == "" || claims.Role == "" {
		return nil, errors.New("missing required jwt claims")
	}

	return claims, nil
}
