import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    @StateObject private var homeRouter = Router()
    @StateObject private var discoveryRouter = Router()
    @StateObject private var trackRouter = Router()
    @StateObject private var profileRouter = Router()

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
            .tabItem { Image(systemName: "magnifyingglass"); Text("Discover") }
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
        .accentColor(Color.mainBlue)
    }
    
    @ViewBuilder
    func handleRouting(for route: AppRoute) -> some View {
        switch route {
        case .loanDetail(let product): LoanDetailScreen(loan: product)
        case .costBreakdown: LoanCostBreakdownView()
        case .loanComparison(let product): LoanComparisonView(loan: product)
        case .eligibilityChecker(let product): EligibilityCheckerView(loan: product)
        case .startApplication(let product): LoanApplicationView(loan: product)
        case .documentUpload: DocumentUploadView()
        case .reviewApplication: ReviewApplicationView()
        case .submitConfirmation: SubmitConfirmationView()
        case .draftApplications: DraftApplicationsView()
        case .detailedTracking: ApplicationTrackingView()
        case .rejectionReason: RejectionStatusView()
        case .emiCalculator: EMICalculatorView()
        case .activeLoanDetails: ActiveLoanDetailsView()
        case .amortisationSchedule: AmortisationScheduleView()
        case .outstandingBalance: OutstandingBalanceView()
        case .repaymentDashboard: RepaymentDashboardView()
        case .repaymentsList(let tab): RepaymentsListView(selectedTab: tab)
        case .overdueDetails: OverdueDetailsView()
        case .paymentCheckout(let amount): PaymentCheckoutView(amount: amount)
        case .paymentSuccess(let txnID): PaymentSuccessView(transactionID: txnID)
        case .prepaymentCalculator: PrepaymentCalculatorView()
        case .whatIfSimulator: WhatIfSimulatorView()
        case .savingsInsight: SavingsInsightView()
        case .credibilityOverview: CredibilityScoreOverviewView()
        case .scoreBreakdown: ScoreBreakdownView()
        case .scoreHistory: ScoreHistoryView()
        case .benefitsUnlocked: BenefitsUnlockedView()
        case .chatList: ChatListView()
        case .chatConversation(let agentName): ChatConversationView(agentName: agentName)
        case .editProfile: EditProfileView()
        case .kycStatus: KYCStatusView()
        case .loanHistory: LoanHistoryView()
        case .settings: SettingsView()
        case .languageSelection: LanguageSelectionView()
        case .accessibilitySettings: AccessibilitySettingsView()
        case .statementDownload: StatementDownloadView()
        case .notifications: NotificationsView()
        case .autoPaySetup: AutoPaySetupView() // NEW: AutoPay Route
        }
    }
}

#Preview {
    let session = SessionStore()
    session.completeSession(name: "Ravi")
    return ContentView()
        .environmentObject(session)
}
