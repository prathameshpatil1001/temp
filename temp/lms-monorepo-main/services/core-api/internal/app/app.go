package app

import (
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/integrations/razorpay"
	transportgrpc "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/http"
)

type Application struct {
	AdminHandler           *transportgrpc.AdminHandler
	AuthHandler            *transportgrpc.AuthHandler
	ChatHandler            *transportgrpc.ChatHandler
	DstHandler             *transportgrpc.DstHandler
	KycHandler             *transportgrpc.KycHandler
	LoanHandler            *transportgrpc.LoanHandler
	QueryHandler           *transportgrpc.QueryHandler
	MediaHandler           *transportgrpc.MediaHandler
	OnboardingHandler      *transportgrpc.OnboardingHandler
	BranchHandler          *transportgrpc.BranchHandler
	RazorpayWebhookHandler *http.RazorpayHandler
}

func New(
	adminService transportgrpc.AdminService,
	authService transportgrpc.AuthService,
	chatService transportgrpc.ChatService,
	dstService transportgrpc.DstService,
	kycService transportgrpc.KycService,
	loanService transportgrpc.LoanService,
	queryService transportgrpc.QueryService,
	mediaService transportgrpc.MediaService,
	onboardingService transportgrpc.OnboardingService,
	branchService transportgrpc.BranchService,
	razorpayClient *razorpay.Client,
) *Application {
	return &Application{
		AdminHandler:           transportgrpc.NewAdminHandler(adminService),
		AuthHandler:            transportgrpc.NewAuthHandler(authService),
		ChatHandler:            transportgrpc.NewChatHandler(chatService),
		DstHandler:             transportgrpc.NewDstHandler(dstService),
		KycHandler:             transportgrpc.NewKycHandler(kycService),
		LoanHandler:            transportgrpc.NewLoanHandler(loanService),
		QueryHandler:           transportgrpc.NewQueryHandler(queryService),
		MediaHandler:           transportgrpc.NewMediaHandler(mediaService),
		OnboardingHandler:      transportgrpc.NewOnboardingHandler(onboardingService),
		BranchHandler:          transportgrpc.NewBranchHandler(branchService),
		RazorpayWebhookHandler: http.NewRazorpayHandler(loanService, razorpayClient),
	}
}
