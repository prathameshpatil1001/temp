//
//  EarningsViewModel.swift
//  LoanApp
//

import Combine
import Foundation
import SwiftUI

@MainActor
class EarningsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var earnings: [Earning] = []
    @Published var stats: EarningsStats?
    @Published var commissionRates: [CommissionRate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Filtering
    @Published var selectedFilter: EarningFilter = .all
    @Published var searchText = ""
    
    // Calculator
    @Published var showCalculator = false
    @Published var showCommissionRates = false
    
    enum EarningFilter: String, CaseIterable {
        case all = "All"
        case paid = "Paid"
        case pending = "Pending"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .paid: return "checkmark.circle"
            case .pending: return "clock"
            }
        }
    }
    
    // MARK: - Dependencies
    private let service: EarningsServiceProtocol
    
    // MARK: - Computed Properties
    var filteredEarnings: [Earning] {
        var filtered = earnings
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .paid:
            filtered = filtered.filter { $0.status == .paid }
        case .pending:
            filtered = filtered.filter { $0.status == .pending }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.customerName.localizedCaseInsensitiveContains(searchText) ||
                $0.loanApplicationId.localizedCaseInsensitiveContains(searchText) ||
                $0.loanType.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by date (most recent first)
        return filtered.sorted { $0.transactionDate > $1.transactionDate }
    }
    
    var earningsByMonth: [(month: String, earnings: [Earning])] {
        let grouped = Dictionary(grouping: filteredEarnings) { earning in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: earning.transactionDate)
        }
        
        return grouped.sorted { first, second in
            guard let firstDate = filteredEarnings.first(where: {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: $0.transactionDate) == first.key
            })?.transactionDate,
            let secondDate = filteredEarnings.first(where: {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: $0.transactionDate) == second.key
            })?.transactionDate else {
                return false
            }
            return firstDate > secondDate
        }.map {
            (month: $0.key,
             earnings: $0.value.sorted { $0.transactionDate > $1.transactionDate })
        }
    }
    
    // MARK: - Initialization
    init(service: EarningsServiceProtocol = MockEarningsService()) {
        self.service = service
    }
    
    // MARK: - API Methods
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let earningsTask = service.fetchEarnings()
            async let statsTask = service.fetchEarningsStats()
            async let ratesTask = service.fetchCommissionRates()
            
            let (fetchedEarnings, fetchedStats, fetchedRates) = try await (earningsTask, statsTask, ratesTask)
            
            earnings = fetchedEarnings
            stats = fetchedStats
            commissionRates = fetchedRates
            
        } catch {
            errorMessage = "Failed to load earnings: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func selectFilter(_ filter: EarningFilter) {
        selectedFilter = filter
    }
    
    func calculateCommission(for loanType: Earning.LoanType, amount: Double) -> Double {
        service.calculateCommission(loanType: loanType, amount: amount)
    }
    
    func getCommissionRates(for loanType: Earning.LoanType) -> [CommissionRate] {
        commissionRates
            .filter { $0.loanType == loanType }
            .sorted { $0.minAmount < $1.minAmount }
    }
    
    // MARK: - Formatting Helpers
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return "₹" + (formatter.string(from: NSNumber(value: amount)) ?? "0")
    }
    
    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: date)
    }
    
    func getExpectedPayoutText(for earning: Earning) -> String {
        if let actualDate = earning.actualPayoutDate {
            return "Paid on \(formatDate(actualDate))"
        } else if let expectedDate = earning.expectedPayoutDate {
            if earning.disbursementDate != nil {
                return "Payout releases after disbursement: expected \(formatDate(expectedDate))"
            } else {
                return "Expected after disbursement"
            }
        }
        return "Pending disbursement"
    }
    
    // MARK: - 🔥 DETAIL SCREEN MAPPING (NEW)
    
    // MARK: - DETAIL SCREEN MAPPING

    func mapToDetail(_ earning: Earning) -> EarningDetail {
        return EarningDetail(
            id: earning.id,
            borrowerName: earning.customerName,
            loanType: earning.loanType.rawValue,
            loanAmount: earning.loanAmount,
            commission: earning.commissionAmount, // ✅ FIXED
            commissionRate: earning.commissionRate,
            status: mapStatus(earning.status),
            disbursementDate: earning.disbursementDate ?? earning.transactionDate,
            
            breakdown: [
                CommissionComponent(title: "Base Commission", amount: earning.commissionAmount * 0.7), // ✅ FIXED
                CommissionComponent(title: "Bonus", amount: earning.commissionAmount * 0.2),
                CommissionComponent(title: "Incentive", amount: earning.commissionAmount * 0.1)
            ],
            
            borrower: Borrower(
                name: earning.customerName,
                phone: "9876543210",
                city: "Mumbai"
            ),
            
            timeline: [
                TimelineStep(title: "Application Submitted", isCompleted: true),
                TimelineStep(title: "Approved", isCompleted: true),
                TimelineStep(title: "Disbursed", isCompleted: earning.disbursementDate != nil),
                TimelineStep(title: "Commission Generated", isCompleted: earning.status != .pending),
                TimelineStep(title: "Payout Released", isCompleted: earning.status == .paid)
            ]
        )
    }

    private func mapStatus(_ status: Earning.EarningStatus) -> EarningPaymentStatus { // ✅ FIXED
        switch status {
        case .paid: return .paid
        case .pending: return .pending
        case .processing: return .processing
        case .cancelled: return .pending // or handle separately if needed
        }
    }

}
