// Features/Home/Shell/MainTabView.swift
// LoanOS Borrower App
// Main authenticated tab shell and centralized tab navigation routing.

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    @StateObject private var homeRouter = AppRouter()
    @StateObject private var discoveryRouter = AppRouter()
    @StateObject private var trackRouter = AppRouter()
    @StateObject private var profileRouter = AppRouter()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            
            // TAB 1: HOME
            NavigationStack(path: $homeRouter.path) {
                HomeDashboardView()
                    .environmentObject(homeRouter)
                    .navigationDestination(for: AppRoute.self) { route in
                        handleRouting(for: route).environmentObject(homeRouter)
                    }
            }
            .tabItem { Image(systemName: "house.fill"); Text("Home") }
            .tag(0)

            // TAB 2: DISCOVER
            NavigationStack(path: $discoveryRouter.path) {
                LoanMarketplaceView()
                    .environmentObject(discoveryRouter)
                    .navigationDestination(for: AppRoute.self) { route in
                        handleRouting(for: route).environmentObject(discoveryRouter)
                    }
            }
            .tabItem { Image(systemName: "plus.circle.fill"); Text("Apply") }
            .tag(1)
            
            // TAB 3: TRACK
            NavigationStack(path: $trackRouter.path) {
                ApplicationStatusListView()
                    .environmentObject(trackRouter)
                    .navigationDestination(for: AppRoute.self) { route in
                        handleRouting(for: route).environmentObject(trackRouter)
                    }
            }
            .tabItem { Image(systemName: "doc.text.magnifyingglass"); Text("Track") }
            .tag(2)
            
            // TAB 4: PROFILE
            NavigationStack(path: $profileRouter.path) {
                ProfileView()
                    .environmentObject(profileRouter)
                    .navigationDestination(for: AppRoute.self) { route in
                        handleRouting(for: route).environmentObject(profileRouter)
                    }
            }
            .tabItem { Image(systemName: "person.fill"); Text("Profile") }
            .tag(3)
        }
        .accentColor(DS.primary)
    }
    
    @ViewBuilder
    func handleRouting(for route: AppRoute) -> some View {
        switch route {
        case .loanDetail(let product): LoanDetailScreen(loan: product)
        case .costBreakdown: LoanCostBreakdownView()
        case .loanComparison(let product): LoanComparisonView(loan: product)
        case .eligibilityChecker(let product): EligibilityCheckerView(loan: product)
        case .startApplication(let product): LoanApplicationView(loan: product)
        case .documentUpload(let application): DocumentUploadView(application: application)
        case .reviewApplication(let application): ReviewApplicationView(application: application)
        case .submitConfirmation(let application): SubmitConfirmationView(application: application)
        case .draftApplications: DraftApplicationsView()
        case .detailedTracking(let application): ApplicationTrackingView(application: application)
        case .rejectionReason(let application): RejectionStatusView(application: application)
        case .emiCalculator: EMICalculatorView()
        case .activeLoanDetails(let application): ActiveLoanDetailsView(application: application)
        case .amortisationSchedule(let loanId): AmortisationScheduleView(loanId: loanId)
        case .outstandingBalance(let loanId, let applicationId): OutstandingBalanceView(loanId: loanId, applicationId: applicationId)
        case .repaymentDashboard(let applicationId): RepaymentDashboardView(applicationId: applicationId)
        case .repaymentsList(let loanId, let tab): RepaymentsListView(loanId: loanId, selectedTab: tab)
        case .overdueDetails(let loanId): OverdueDetailsView(loanId: loanId)
        case .paymentCheckout(let loanId, let emiScheduleId, let amount): PaymentCheckoutView(loanId: loanId, emiScheduleId: emiScheduleId, amount: amount)
        case .paymentSuccess(let txnID): PaymentSuccessView(transactionID: txnID)
        case .prepaymentCalculator: PrepaymentCalculatorView()
        case .whatIfSimulator: WhatIfSimulatorView()
        case .savingsInsight: SavingsInsightView()
        case .credibilityOverview(let score): CredibilityScoreOverviewView(score: score)
        case .scoreBreakdown: ScoreBreakdownView()
        case .scoreHistory: ScoreHistoryView()
        case .benefitsUnlocked(let score): BenefitsUnlockedView(score: score)
        case .chatList: ChatListView()
        case .chatConversation(let roomID): ChatConversationView(roomID: roomID)
        case .editProfile: EditProfileView()
        case .kycStatus: KYCStatusView()
        case .loanHistory: LoanHistoryView()
        case .settings: SettingsView()
        case .languageSelection: LanguageSelectionView()
        case .accessibilitySettings: AccessibilitySettingsView()
        case .statementDownload: StatementDownloadView()
        case .notifications: AppNotificationsView()
        case .autoPaySetup: AutoPaySetupView() // NEW: AutoPay Route
        }
    }
}

#Preview {
    let session = SessionStore()
    session.completeSession(name: "Ravi")
    return MainTabView()
        .environmentObject(session)
}
