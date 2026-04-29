package server

import (
	"context"
	"fmt"
	"log"
	"net"
	"time"

	"net/http"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/app"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/audit"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/config"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/db"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/r2"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/razorpay"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/sandbox"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/admin"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/auth"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/branch"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/chat"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/dst"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/kyc"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/loan"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/media"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/onboarding"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/service/query"
	adminv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/adminv1"
	authv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/authv1"
	branchv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/branchv1"
	chatv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/chatv1"
	dstv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/dstv1"
	kycv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/kycv1"
	loanv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/loanv1"
	mediav1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/mediav1"
	onboardingv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/onboardingv1"
	queryv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/queryv1"
	grpcinterceptors "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	grpc_health_v1 "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"
)

func Run() error {
	cfg := config.Load()

	redisClient, err := db.NewRedisClient(context.Background(), cfg.RedisAddr, cfg.RedisPass)
	if err != nil {
		return fmt.Errorf("failed to connect to redis: %w", err)
	}
	defer redisClient.Close()

	pgPool, err := db.NewPostgresPool(context.Background(), cfg.PostgresDSN)
	if err != nil {
		return fmt.Errorf("failed to connect to postgres: %w", err)
	}
	defer pgPool.Close()

	queries := generated.New(pgPool)

	auditService := audit.NewService(queries)

	lis, err := net.Listen("tcp", ":"+cfg.GRPCPort)
	if err != nil {
		return fmt.Errorf("listen on grpc port %s: %w", cfg.GRPCPort, err)
	}

	adminService := admin.NewService(queries)
	authService := auth.NewService(queries, redisClient, cfg)
	chatService := chat.NewService(queries)
	dstService := dst.NewService(queries)
	sandboxKYCClient := sandbox.NewKYCClient(cfg.SandboxBaseURL, cfg.SandboxAPIKey, cfg.SandboxSecret)
	kycService := kyc.NewService(pgPool, queries, sandboxKYCClient)
	razorpayClient := razorpay.NewClient(cfg.RazorpayKeyID, cfg.RazorpayKeySecret)
	loanService := loan.NewService(queries, auditService, razorpayClient)
	queryService := query.NewService(queries)
	r2Client, err := r2.NewClient(context.Background(), cfg.R2AccountID, cfg.R2AccessKeyID, cfg.R2SecretAccessKey, cfg.R2BucketName, cfg.R2PublicBaseURL)
	if err != nil {
		return fmt.Errorf("failed to initialize r2 client: %w", err)
	}
	mediaService := media.NewService(queries, r2Client, time.Duration(cfg.R2UploadURLTTLSecs)*time.Second, cfg.MediaMaxUploadSize)
	onboardingService := onboarding.NewService(queries, redisClient, cfg)
	branchService := branch.NewService(queries)
	application := app.New(adminService, authService, chatService, dstService, kycService, loanService, queryService, mediaService, onboardingService, branchService, razorpayClient)

	publicMethods := map[string]struct{}{
		// BOOTSTRAP ADMIN ONLY:
		// Keep this line uncommented only for initial setup environments where the first admin
		// must be created without authentication. Comment this line in production to disable
		// unauthenticated admin bootstrap account creation.
		"/admin.v1.AdminService/CreateAdminAccount":                      {}, // PRODUCTION: keep commented out; uncomment only for initial admin bootstrap
		"/auth.v1.AuthService/Hello":                                     {},
		"/auth.v1.AuthService/InitiateSignup":                            {},
		"/auth.v1.AuthService/VerifySignupOTPs":                          {},
		"/auth.v1.AuthService/LoginPrimary":                              {},
		"/auth.v1.AuthService/InitiateReopen":                            {},
		"/auth.v1.AuthService/SelectLoginMFAFactor":                      {},
		"/auth.v1.AuthService/VerifyLoginMFA":                            {},
		"/auth.v1.AuthService/InitiateForgotPassword":                    {},
		"/auth.v1.AuthService/VerifyForgotPasswordOTPs":                  {},
		"/auth.v1.AuthService/ResetForgotPassword":                       {},
		"/auth.v1.AuthService/RefreshToken":                              {},
		"/auth.v1.AuthService/GetOfficerProfileByUserID":                 {},
		"/auth.v1.AuthService/GetManagerProfileByUserID":                 {},
		"/grpc.health.v1.Health/Check":                                   {},
		"/grpc.health.v1.Health/Watch":                                   {},
		"/grpc.reflection.v1.ServerReflection/ServerReflectionInfo":      {},
		"/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo": {},
	}

	rbacPolicy := grpcinterceptors.RBACPolicy{
		"/admin.v1.AdminService/CreateEmployeeAccount":                {"admin"},
		"/admin.v1.AdminService/ListEmployeeAccounts":                 {"admin"},
		"/admin.v1.AdminService/ListBranchOfficers":                   {"manager", "admin"},
		"/admin.v1.AdminService/CreateDstAccount":                     {"manager"},
		"/admin.v1.AdminService/UpdateDstAccount":                     {"manager", "admin"},
		"/admin.v1.AdminService/CreateBankBranch":                     {"admin"},
		"/admin.v1.AdminService/UpdateBankBranch":                     {"admin"},
		"/admin.v1.AdminService/DeleteBankBranch":                     {"admin"},
		"/admin.v1.AdminService/UpdateBranchDstCommission":            {"manager", "admin"},
		"/admin.v1.AdminService/UpdateEmployeeAccount":                {"admin"},
		"/admin.v1.AdminService/DeleteEmployeeAccount":                {"admin"},
		"/admin.v1.AdminService/AssignEmployeeBranch":                 {"admin"},
		"/auth.v1.AuthService/GetBorrowerProfile":                     {"borrower", "officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/GetUser":                                {"borrower", "officer", "manager", "admin", "dst"},
		"/dst.v1.DstService/GetDstAccount":                            {"manager", "admin"},
		"/dst.v1.DstService/ListDstAccounts":                          {"manager", "admin"},
		"/auth.v1.AuthService/SetupTOTP":                              {"borrower", "officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/VerifyTOTPSetup":                        {"borrower", "officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/GetMyProfile":                           {"borrower", "officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/SearchBorrowerSignupStatus":             {"officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/ChangePassword":                         {"borrower", "officer", "manager", "admin", "dst"},
		"/kyc.v1.KycService/RecordUserConsent":                        {"borrower", "officer", "manager", "admin", "dst"},
		"/kyc.v1.KycService/InitiateAadhaarKyc":                       {"borrower", "officer", "manager", "admin", "dst"},
		"/kyc.v1.KycService/VerifyAadhaarKycOtp":                      {"borrower", "officer", "manager", "admin", "dst"},
		"/kyc.v1.KycService/VerifyPanKyc":                             {"borrower", "officer", "manager", "admin", "dst"},
		"/kyc.v1.KycService/GetBorrowerKycStatus":                     {"borrower", "officer", "manager", "admin", "dst"},
		"/kyc.v1.KycService/ListBorrowerKycHistory":                   {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/CreateLoanProduct":                      {"admin"},
		"/loan.v1.LoanService/UpdateLoanProduct":                      {"admin"},
		"/loan.v1.LoanService/DeleteLoanProduct":                      {"admin"},
		"/loan.v1.LoanService/GetLoanProduct":                         {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/ListLoanProducts":                       {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/UpsertProductEligibilityRule":           {"admin"},
		"/loan.v1.LoanService/ReplaceProductFees":                     {"admin"},
		"/loan.v1.LoanService/ReplaceProductRequiredDocuments":        {"admin"},
		"/loan.v1.LoanService/CreateLoanApplication":                  {"borrower", "officer", "dst"},
		"/loan.v1.LoanService/GetLoanApplication":                     {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/ListLoanApplications":                   {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/UpdateLoanApplicationStatus":            {"officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/UpdateLoanApplicationTerms":             {"officer", "manager", "admin"},
		"/loan.v1.LoanService/AssignLoanApplicationOfficer":           {"manager", "admin"},
		"/loan.v1.LoanService/AddApplicationCoapplicant":              {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/UpsertApplicationCollateral":            {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/UpsertLoanVehicle":                      {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/UpsertLoanRealEstate":                   {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/AddApplicationDocument":                 {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/UpdateApplicationDocumentVerification":  {"officer", "manager", "admin"},
		"/loan.v1.LoanService/AddBureauScore":                         {"officer", "manager", "admin"},
		"/loan.v1.LoanService/CreateLoan":                             {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/GetLoan":                                {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/ListLoans":                              {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/AddEmiScheduleItem":                     {"manager", "admin"},
		"/loan.v1.LoanService/ListEmiSchedule":                        {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/RecordPayment":                          {"officer", "manager", "admin"},
		"/loan.v1.LoanService/ListPayments":                           {"borrower", "officer", "manager", "admin", "dst"},
		"/loan.v1.LoanService/InitiatePayment":                        {"borrower"},
		"/loan.v1.LoanService/VerifyPayment":                          {"borrower"},
		"/query.v1.QueryService/CreateLoanQuery":                      {"borrower"},
		"/query.v1.QueryService/GetLoanQuery":                         {"borrower", "officer", "manager", "admin"},
		"/query.v1.QueryService/ListLoanQueries":                      {"borrower", "officer", "manager", "admin"},
		"/query.v1.QueryService/UpdateLoanQueryStatus":                {"manager", "admin"},
		"/media.v1.MediaService/InitiateMediaUpload":                  {"borrower", "officer", "manager", "admin", "dst"},
		"/media.v1.MediaService/CompleteMediaUpload":                  {"borrower", "officer", "manager", "admin", "dst"},
		"/media.v1.MediaService/ListMedia":                            {"borrower", "officer", "manager", "admin", "dst"},
		"/onboarding.v1.OnboardingService/CompleteBorrowerOnboarding": {"borrower", "officer", "manager", "admin", "dst"},
		"/onboarding.v1.OnboardingService/UpdateBorrowerProfile":      {"borrower", "officer", "manager", "admin", "dst"},
		"/auth.v1.AuthService/Logout":                                 {"borrower", "officer", "manager", "admin", "dst"},
		"/branch.v1.BranchService/ListBranches":                       {"borrower", "officer", "manager", "admin", "dst"},
		"/chat.v1.ChatService/ListChatEligibleUsers":                  {"borrower", "officer", "manager", "admin", "dst"},
		"/chat.v1.ChatService/CreateOrGetDirectRoom":                  {"borrower", "officer", "manager", "admin", "dst"},
		"/chat.v1.ChatService/ListMyChatRooms":                        {"borrower", "officer", "manager", "admin", "dst"},
		"/chat.v1.ChatService/ListRoomMessages":                       {"borrower", "officer", "manager", "admin", "dst"},
		"/chat.v1.ChatService/SendMessage":                            {"borrower", "officer", "manager", "admin", "dst"},
		"/chat.v1.ChatService/SubscribeRoomMessages":                  {"borrower", "officer", "manager", "admin", "dst"},
	}

	grpcServer := grpc.NewServer(
		grpc.ChainUnaryInterceptor(
			grpcinterceptors.LoggingUnaryInterceptor(auditService),
			grpcinterceptors.JWTUnaryInterceptor(grpcinterceptors.JWTConfig{
				SigningKey:    []byte(cfg.JWTKey),
				RedisClient:   redisClient,
				PublicMethods: publicMethods,
			}),
			grpcinterceptors.RBACUnaryInterceptor(rbacPolicy),
		),
		grpc.ChainStreamInterceptor(
			grpcinterceptors.LoggingStreamInterceptor(),
			grpcinterceptors.JWTStreamInterceptor(grpcinterceptors.JWTConfig{
				SigningKey:    []byte(cfg.JWTKey),
				RedisClient:   redisClient,
				PublicMethods: publicMethods,
			}),
			grpcinterceptors.RBACStreamInterceptor(rbacPolicy),
		),
	)

	healthServer := health.NewServer()
	healthServer.SetServingStatus("", grpc_health_v1.HealthCheckResponse_SERVING)
	grpc_health_v1.RegisterHealthServer(grpcServer, healthServer)

	adminv1.RegisterAdminServiceServer(grpcServer, application.AdminHandler)
	authv1.RegisterAuthServiceServer(grpcServer, application.AuthHandler)
	chatv1.RegisterChatServiceServer(grpcServer, application.ChatHandler)
	dstv1.RegisterDstServiceServer(grpcServer, application.DstHandler)
	kycv1.RegisterKycServiceServer(grpcServer, application.KycHandler)
	loanv1.RegisterLoanServiceServer(grpcServer, application.LoanHandler)
	queryv1.RegisterQueryServiceServer(grpcServer, application.QueryHandler)
	mediav1.RegisterMediaServiceServer(grpcServer, application.MediaHandler)
	onboardingv1.RegisterOnboardingServiceServer(grpcServer, application.OnboardingHandler)
	branchv1.RegisterBranchServiceServer(grpcServer, application.BranchHandler)
	reflection.Register(grpcServer)

	go func() {
		log.Printf("http server (webhooks) listening on :%s", cfg.HTTPPort)
		mux := http.NewServeMux()
		mux.Handle("/webhooks/razorpay", application.RazorpayWebhookHandler)
		if err := http.ListenAndServe(":"+cfg.HTTPPort, mux); err != nil {
			log.Printf("http server error: %v", err)
		}
	}()

	log.Printf("grpc server listening on :%s", cfg.GRPCPort)
	return grpcServer.Serve(lis)
}
