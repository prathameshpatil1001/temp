package util

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type TokenPair struct {
	AccessToken  string
	RefreshToken string
}

func MintTokens(ctx context.Context, queries generated.Querier, redisClient redis.Cmdable, jwtKey string, userID uuid.UUID, role, deviceID string) (*TokenPair, error) {
	jti := uuid.New().String()

	user, err := queries.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to fetch user for token minting")
	}

	claims := interceptors.AuthClaims{
		Role:                      role,
		IsActive:                  user.IsActive.Bool,
		IsRequiringPasswordChange: user.IsRequiringPasswordChange.Bool,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			ID:        jti,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	accessToken, _ := token.SignedString([]byte(jwtKey))

	refreshToken := uuid.New().String()
	hash := sha256.Sum256([]byte(refreshToken))
	hashedToken := hex.EncodeToString(hash[:])

	expiresAt := time.Now().Add(7 * 24 * time.Hour)
	_, err = queries.CreateRefreshToken(ctx, generated.CreateRefreshTokenParams{
		UserID:      pgtype.UUID{Bytes: userID, Valid: true},
		DeviceID:    deviceID,
		HashedToken: hashedToken,
		ExpiresAt:   pgtype.Timestamptz{Time: expiresAt, Valid: true},
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to persist refresh token")
	}

	err = redisClient.Set(ctx, fmt.Sprintf("active_token:%s", userID.String()), jti, 15*time.Minute).Err()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to set active session")
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}, nil
}