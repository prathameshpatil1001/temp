package config

import (
	"os"
	"strconv"
)

type Config struct {
	GRPCPort string
	JWTKey   string

	PostgresDSN string
	RedisAddr   string
	RedisPass   string

	WebAuthnRPID          string
	WebAuthnRPOrigins     string
	WebAuthnRPDisplayName string

	SandboxBaseURL string
	SandboxAPIKey  string
	SandboxSecret  string

	R2AccountID        string
	R2AccessKeyID      string
	R2SecretAccessKey  string
	R2BucketName       string
	R2PublicBaseURL    string
	R2UploadURLTTLSecs int
	MediaMaxUploadSize int64

	HTTPPort              string
	RazorpayKeyID         string
	RazorpayKeySecret     string
	RazorpayWebhookSecret string
}

func Load() Config {
	return Config{
		GRPCPort:    envOrDefault("GRPC_PORT", "8080"),
		HTTPPort:    envOrDefault("HTTP_PORT", "8081"),
		JWTKey:      envOrDefault("JWT_SIGNING_KEY", "dev-only-change-me"),
		PostgresDSN: envOrDefault("POSTGRES_DSN", "postgres://lms:lms@localhost:5432/lms?sslmode=disable"),
		RedisAddr:   envOrDefault("REDIS_ADDR", "localhost:6379"),
		RedisPass:   os.Getenv("REDIS_PASSWORD"),

		WebAuthnRPID:          envOrDefault("WEBAUTHN_RP_ID", "localhost"),
		WebAuthnRPOrigins:     envOrDefault("WEBAUTHN_RP_ORIGINS", "http://localhost:3000"),
		WebAuthnRPDisplayName: envOrDefault("WEBAUTHN_RP_DISPLAY_NAME", "LMS Monorepo"),

		SandboxBaseURL: envOrDefault("SANDBOX_BASE_URL", "https://api.sandbox.co.in"),
		SandboxAPIKey:  os.Getenv("SANDBOX_API_KEY"),
		SandboxSecret:  os.Getenv("SANDBOX_API_SECRET"),

		R2AccountID:        os.Getenv("R2_ACCOUNT_ID"),
		R2AccessKeyID:      os.Getenv("R2_ACCESS_KEY_ID"),
		R2SecretAccessKey:  os.Getenv("R2_SECRET_ACCESS_KEY"),
		R2BucketName:       os.Getenv("R2_BUCKET_NAME"),
		R2PublicBaseURL:    os.Getenv("R2_PUBLIC_BASE_URL"),
		R2UploadURLTTLSecs: envIntOrDefault("R2_UPLOAD_URL_TTL_SECONDS", 900),
		MediaMaxUploadSize: envInt64OrDefault("MEDIA_MAX_UPLOAD_BYTES", 10485760),

		RazorpayKeyID:         os.Getenv("RAZORPAY_KEY_ID"),
		RazorpayKeySecret:     os.Getenv("RAZORPAY_KEY_SECRET"),
		RazorpayWebhookSecret: os.Getenv("RAZORPAY_WEBHOOK_SECRET"),
	}
}

func envOrDefault(key, fallback string) string {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	return v
}

func envIntOrDefault(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return parsed
}

func envInt64OrDefault(key string, fallback int64) int64 {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	parsed, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		return fallback
	}
	return parsed
}
