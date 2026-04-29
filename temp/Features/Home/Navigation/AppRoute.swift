// Features/Home/Navigation/AppRoute.swift
// LoanOS Borrower App
// Defines all navigation destinations available from home flows.

import SwiftUI

enum AppRoute: Hashable {
    // Discovery
    case loanDetail(LoanProduct)
    case costBreakdown
    case loanComparison(LoanProduct)
    case eligibilityChecker(LoanProduct)
    
    // Application Flow
    case startApplication(LoanProduct)
    case documentUpload(BorrowerLoanApplication)
    case reviewApplication(BorrowerLoanApplication)
    case submitConfirmation(BorrowerLoanApplication)
    case draftApplications
    
    // Tracking
    case detailedTracking(BorrowerLoanApplication)
    case rejectionReason(BorrowerLoanApplication)
    
    // Feature 7: EMI & Loan Management
    case emiCalculator
    case activeLoanDetails(BorrowerLoanApplication)
    case amortisationSchedule(loanId: String?)
    case outstandingBalance(loanId: String, applicationId: String)
    
    // Feature 8: Repayment Module
    case repaymentDashboard(applicationId: String)
    case repaymentsList(loanId: String, initialTab: Int)
    case overdueDetails(loanId: String)
    case paymentCheckout(loanId: String, emiScheduleId: String, amount: Double)
    case paymentSuccess(transactionID: String)
    case autoPaySetup // No backend API – shows fallback alert
    
    // Feature 9: Smart Financial Tools
    case prepaymentCalculator
    case whatIfSimulator
    case savingsInsight
    
    // Feature 10: Credibility Score
    case credibilityOverview(score: Int)
    case scoreBreakdown
    case scoreHistory
    case benefitsUnlocked(score: Int)
    
    // Feature 11: Messaging
    case chatList
    case chatConversation(roomID: String)
    
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
