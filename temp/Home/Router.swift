import SwiftUI
import Combine

// 1. Define all possible destinations in your app
enum AppRoute: Hashable {
    // Discovery
    case loanDetail(LoanProduct)
    case costBreakdown
    case loanComparison(LoanProduct)
    case eligibilityChecker(LoanProduct)
    
    // Application Flow
    case startApplication(LoanProduct)
    case documentUpload
    case reviewApplication
    case submitConfirmation
    case draftApplications
    
    // Tracking
    case detailedTracking
    case rejectionReason
    
    // Feature 7: EMI & Loan Management
    case emiCalculator
    case activeLoanDetails
    case amortisationSchedule
    case outstandingBalance
    
    // Feature 8: Repayment Module
    case repaymentDashboard
    case repaymentsList(initialTab: Int)
    case overdueDetails
    case paymentCheckout(amount: Double)
    case paymentSuccess(transactionID: String)
    case autoPaySetup // NEW: AutoPay Route
    
    // Feature 9: Smart Financial Tools
    case prepaymentCalculator
    case whatIfSimulator
    case savingsInsight
    
    // Feature 10: Credibility Score
    case credibilityOverview
    case scoreBreakdown
    case scoreHistory
    case benefitsUnlocked
    
    // Feature 11: Messaging
    case chatList
    case chatConversation(agentName: String)
    
    // Feature 12: Profile & Settings
    case editProfile
    case kycStatus
    case loanHistory
    case settings
    case languageSelection
    case accessibilitySettings
    
    // Dashboard Utilities
    case statementDownload
    case notifications
}

// 2. Create an Observable Router to manage the navigation stack
class Router: ObservableObject {
    @Published var path = NavigationPath()
    
    func push(_ route: AppRoute) {
        path.append(route)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}
