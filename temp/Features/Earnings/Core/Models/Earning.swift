//
//  Earning.swift
//  LoanApp
//
//  Core/Models/Earning.swift
//

import Foundation

// MARK: - Earning Transaction
struct Earning: Identifiable, Codable {
    let id: String
    let loanApplicationId: String
    let customerName: String
    let loanType: LoanType
    let loanAmount: Double
    let commissionRate: Double
    let commissionAmount: Double
    let status: EarningStatus
    let transactionDate: Date
    let expectedPayoutDate: Date?
    let actualPayoutDate: Date?
    let disbursementDate: Date?
    
    enum LoanType: String, Codable, CaseIterable {
        case homeLoan = "Home Loan"
        case personalLoan = "Personal Loan"
        case businessLoan = "Business Loan"
        case autoLoan = "Auto Loan"
        case educationLoan = "Education Loan"
        
        var icon: String {
            switch self {
            case .homeLoan: return "house.fill"
            case .personalLoan: return "person.fill"
            case .businessLoan: return "briefcase.fill"
            case .autoLoan: return "car.fill"
            case .educationLoan: return "book.fill"
            }
        }
    }
    
    enum EarningStatus: String, Codable {
        case pending = "Pending"
        case paid = "Paid"
        case processing = "Processing"
        case cancelled = "Cancelled"
        
        var color: String {
            switch self {
            case .pending: return "orange"
            case .paid: return "green"
            case .processing: return "blue"
            case .cancelled: return "red"
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .paid: return "checkmark.circle"
            case .processing: return "arrow.clockwise"
            case .cancelled: return "xmark.circle"
            }
        }
    }
}

// MARK: - Commission Rate
struct CommissionRate: Identifiable, Codable {
    let id: String
    let loanType: Earning.LoanType
    let minAmount: Double
    let maxAmount: Double?
    let rate: Double
    let description: String
    
    var formattedRange: String {
        if let max = maxAmount {
            return "₹\(formatAmount(minAmount)) - ₹\(formatAmount(max))"
        } else {
            return "₹\(formatAmount(minAmount))+"
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount >= 10000000 {
            return String(format: "%.1fCr", amount / 10000000)
        } else if amount >= 100000 {
            return String(format: "%.1fL", amount / 100000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}

// MARK: - Earnings Statistics
struct EarningsStats: Codable {
    let totalLifetimeEarnings: Double
    let thisMonthEarnings: Double
    let pendingPayout: Double
    let paidTransactionsCount: Int
    let pendingTransactionsCount: Int
    let averagePayoutRate: Double
    let totalTransactionsCount: Int
    
    var formattedLifetimeEarnings: String {
        "₹\(formatCurrency(totalLifetimeEarnings))"
    }
    
    var formattedMonthEarnings: String {
        "₹\(formatCurrency(thisMonthEarnings))"
    }
    
    var formattedPendingPayout: String {
        "₹\(formatCurrency(pendingPayout))"
    }
    
    var formattedAverageRate: String {
        String(format: "%.1f%%", averagePayoutRate)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

// MARK: - Commission Calculator Input
struct CommissionCalculation {
    let loanType: Earning.LoanType
    let loanAmount: Double
    
    var estimatedCommission: Double {
        // Default rates - should come from CommissionRate service
        let rate: Double
        switch loanType {
        case .homeLoan:
            rate = loanAmount >= 5000000 ? 0.015 : 0.012
        case .personalLoan:
            rate = 0.02
        case .businessLoan:
            rate = loanAmount >= 10000000 ? 0.018 : 0.015
        case .autoLoan:
            rate = 0.01
        case .educationLoan:
            rate = 0.013
        }
        return loanAmount * rate
    }
    
    var formattedCommission: String {
        "₹\(formatCurrency(estimatedCommission))"
    }
    
    var formattedLoanAmount: String {
        "₹\(formatCurrency(loanAmount))"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}
