package interceptors

import (
	"context"
	"log"
	"strings"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/audit"
	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// LoggingUnaryInterceptor logs one line per unary request with method, duration,
// status code, and identity metadata when available.
func LoggingUnaryInterceptor(auditSvc audit.AuditService) grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
		started := time.Now()

		identity := &Identity{}
		ctx = context.WithValue(ctx, ContextIdentityKey, identity)

		resp, err := handler(ctx, req)

		userID := ""
		if identity.UserID != uuid.Nil {
			userID = identity.UserID.String()
		}

		role := identity.Role

		requestID := ""
		ipAddress := ""
		userAgent := ""
		if md, ok := metadata.FromIncomingContext(ctx); ok {
			if values := md.Get("x-request-id"); len(values) > 0 {
				requestID = values[0]
			}
			if values := md.Get("x-forwarded-for"); len(values) > 0 {
				ipAddress = values[0]
			}
			if values := md.Get("user-agent"); len(values) > 0 {
				userAgent = values[0]
			}
		}

		code := status.Code(err)
		log.Printf(
			"grpc_request method=%s code=%s duration_ms=%d user_id=%s role=%s request_id=%s",
			info.FullMethod,
			code.String(),
			time.Since(started).Milliseconds(),
			userID,
			role,
			requestID,
		)

		// Perform audit logging for mutating methods
		if auditSvc != nil && isMutatingMethod(info.FullMethod) && code == codes.OK {
			auditSvc.Record(ctx, audit.AuditEntry{
				ActorID:    identity.UserID,
				ActorRole:  identity.Role,
				Action:     info.FullMethod,
				Payload:    req,
				StatusCode: code.String(),
				IPAddress:  ipAddress,
				UserAgent:  userAgent,
			})
		}

		return resp, err
	}
}

func isMutatingMethod(method string) bool {
	parts := strings.Split(method, "/")
	if len(parts) < 3 {
		return false
	}
	methodName := parts[len(parts)-1]
	mutatingPrefixes := []string{"Create", "Update", "Delete", "Record", "Add", "Upsert", "Replace", "Assign", "Complete", "Initiate"}
	for _, prefix := range mutatingPrefixes {
		if strings.HasPrefix(methodName, prefix) {
			return true
		}
	}
	return false
}

// LoggingStreamInterceptor logs one line per streaming RPC with method, duration,
// status code, and identity metadata when available.
func LoggingStreamInterceptor() grpc.StreamServerInterceptor {
	return func(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
		started := time.Now()

		identity := &Identity{}
		ctx := context.WithValue(ss.Context(), ContextIdentityKey, identity)

		wrapped := &wrappedServerStreamForLogging{ServerStream: ss, ctx: ctx}

		err := handler(srv, wrapped)

		userID := ""
		if identity.UserID != uuid.Nil {
			userID = identity.UserID.String()
		}

		role := identity.Role

		requestID := ""
		if md, ok := metadata.FromIncomingContext(ctx); ok {
			if values := md.Get("x-request-id"); len(values) > 0 {
				requestID = values[0]
			}
		}

		code := status.Code(err)
		log.Printf(
			"grpc_stream method=%s code=%s duration_ms=%d user_id=%s role=%s request_id=%s",
			info.FullMethod,
			code.String(),
			time.Since(started).Milliseconds(),
			userID,
			role,
			requestID,
		)

		return err
	}
}

// wrappedServerStreamForLogging wraps grpc.ServerStream to carry an overridden context.
type wrappedServerStreamForLogging struct {
	grpc.ServerStream
	ctx context.Context
}

func (w *wrappedServerStreamForLogging) Context() context.Context { return w.ctx }
