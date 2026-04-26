//
//  EarningsService.swift
//  LoanApp
//
//  Core/Services/EarningsService.swift
//

import Foundation

// MARK: - Earnings Service Protocol
protocol EarningsServiceProtocol {
    func fetchEarnings() async throws -> [Earning]
    func fetchEarningsStats() async throws -> EarningsStats
    func fetchCommissionRates() async throws -> [CommissionRate]
    func calculateCommission(loanType: Earning.LoanType, amount: Double) -> Double
}

// MARK: - Mock Earnings Service
class MockEarningsService: EarningsServiceProtocol {
    
    func fetchEarnings() async throws -> [Earning] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return [
            Earning(
                id: "E001",
                loanApplicationId: "A002",
                customerName: "Arjun Mehta",
                loanType: .homeLoan,
                loanAmount: 7500000,
                commissionRate: 1.2,
                commissionAmount: 8750,
                status: .paid,
                transactionDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
                expectedPayoutDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                actualPayoutDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                disbursementDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            ),
            Earning(
                id: "E002",
                loanApplicationId: "A004",
                customerName: "Priya Sharma",
                loanType: .personalLoan,
                loanAmount: 500000,
                commissionRate: 2.0,
                commissionAmount: 2400,
                status: .paid,
                transactionDate: Calendar.current.date(byAdding: .day, value: -9, to: Date())!,
                expectedPayoutDate: Calendar.current.date(byAdding: .day, value: -6, to: Date())!,
                actualPayoutDate: Calendar.current.date(byAdding: .day, value: -6, to: Date())!,
                disbursementDate: Calendar.current.date(byAdding: .day, value: -11, to: Date())!
            ),
            Earning(
                id: "E003",
                loanApplicationId: "A001",
                customerName: "Rohit Verma",
                loanType: .businessLoan,
                loanAmount: 12500000,
                commissionRate: 1.5,
                commissionAmount: 15000,
                status: .pending,
                transactionDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                expectedPayoutDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
                actualPayoutDate: nil,
                disbursementDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            ),
            Earning(
                id: "E004",
                loanApplicationId: "A003",
                customerName: "Kavitha Nair",
                loanType: .homeLoan,
                loanAmount: 3500000,
                commissionRate: 1.2,
                commissionAmount: 0,
                status: .pending,
                transactionDate: Date(),
                expectedPayoutDate: Calendar.current.date(byAdding: .day, value: 21, to: Date())!,
                actualPayoutDate: nil,
                disbursementDate: nil
            ),
            Earning(
                id: "E005",
                loanApplicationId: "A008",
                customerName: "Sanjay Desai",
                loanType: .autoLoan,
                loanAmount: 1200000,
                commissionRate: 1.0,
                commissionAmount: 12000,
                status: .paid,
                transactionDate: Calendar.current.date(byAdding: .day, value: -18, to: Date())!,
                expectedPayoutDate: Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
                actualPayoutDate: Calendar.current.date(byAdding: .day, value: -15, to: Date())!,
                disbursementDate: Calendar.current.date(byAdding: .day, value: -20, to: Date())!
            ),
            Earning(
                id: "E006",
                loanApplicationId: "A012",
                customerName: "Meera Iyer",
                loanType: .educationLoan,
                loanAmount: 800000,
                commissionRate: 1.3,
                commissionAmount: 10400,
                status: .paid,
                transactionDate: Calendar.current.date(byAdding: .day, value: -25, to: Date())!,
                expectedPayoutDate: Calendar.current.date(byAdding: .day, value: -22, to: Date())!,
                actualPayoutDate: Calendar.current.date(byAdding: .day, value: -22, to: Date())!,
                disbursementDate: Calendar.current.date(byAdding: .day, value: -27, to: Date())!
            )
        ]
    }
    
    func fetchEarningsStats() async throws -> EarningsStats {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        return EarningsStats(
            totalLifetimeEarnings: 234600,
            thisMonthEarnings: 26550,
            pendingPayout: 15000,
            paidTransactionsCount: 4,
            pendingTransactionsCount: 2,
            averagePayoutRate: 1.2,
            totalTransactionsCount: 6
        )
    }
    
    func fetchCommissionRates() async throws -> [CommissionRate] {
        try await Task.sleep(nanoseconds: 200_000_000)
        
        return [
            CommissionRate(
                id: "CR1",
                loanType: .homeLoan,
                minAmount: 0,
                maxAmount: 5000000,
                rate: 1.2,
                description: "Standard home loan commission"
            ),
            CommissionRate(
                id: "CR2",
                loanType: .homeLoan,
                minAmount: 5000000,
                maxAmount: nil,
                rate: 1.5,
                description: "Premium home loan commission"
            ),
            CommissionRate(
                id: "CR3",
                loanType: .personalLoan,
                minAmount: 0,
                maxAmount: nil,
                rate: 2.0,
                description: "Personal loan commission"
            ),
            CommissionRate(
                id: "CR4",
                loanType: .businessLoan,
                minAmount: 0,
                maxAmount: 10000000,
                rate: 1.5,
                description: "Standard business loan commission"
            ),
            CommissionRate(
                id: "CR5",
                loanType: .businessLoan,
                minAmount: 10000000,
                maxAmount: nil,
                rate: 1.8,
                description: "Large business loan commission"
            ),
            CommissionRate(
                id: "CR6",
                loanType: .autoLoan,
                minAmount: 0,
                maxAmount: nil,
                rate: 1.0,
                description: "Auto loan commission"
            ),
            CommissionRate(
                id: "CR7",
                loanType: .educationLoan,
                minAmount: 0,
                maxAmount: nil,
                rate: 1.3,
                description: "Education loan commission"
            )
        ]
    }
    
    func calculateCommission(loanType: Earning.LoanType, amount: Double) -> Double {
        let rate: Double
        switch loanType {
        case .homeLoan:
            rate = amount >= 5000000 ? 0.015 : 0.012
        case .personalLoan:
            rate = 0.02
        case .businessLoan:
            rate = amount >= 10000000 ? 0.018 : 0.015
        case .autoLoan:
            rate = 0.01
        case .educationLoan:
            rate = 0.013
        }
        return amount * rate
    }
}
