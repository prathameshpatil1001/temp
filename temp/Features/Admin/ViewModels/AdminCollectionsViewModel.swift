//
//  AdminCollectionsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - Collection Models

struct OverdueLoan: Identifiable, Hashable {
    let id: String
    let applicationId: String
    let borrowerName: String
    let loanType: String
    let emi: Double
    let dpd: Int           // Days Past Due
    let outstanding: Double
    var assignedAgent: String
    var isNPA: Bool
    var settlementOffered: Bool
}

struct RecoveryAgent: Identifiable, Hashable {
    let id: String
    let name: String
    let assignedCount: Int
    let recoveryRate: Double   // 0–1
}

struct EMIRecord: Identifiable, Hashable {
    let id: String
    let month: String
    let dueDate: Date
    let amount: Double
    var paid: Bool
    var paidDate: Date?
}

// MARK: - Admin Collections View Model

class AdminCollectionsViewModel: ObservableObject {

    @Published var overdueLoans: [OverdueLoan] = []
    @Published var agents: [RecoveryAgent] = []
    @Published var selectedLoan: OverdueLoan? = nil
    @Published var showSettlementSheet = false
    @Published var settlementNote = ""
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    @Published var isLoading = false

    // MARK: - DPD Buckets

    var bucket30: [OverdueLoan] { overdueLoans.filter { $0.dpd >= 1  && $0.dpd < 31  && !$0.isNPA } }
    var bucket60: [OverdueLoan] { overdueLoans.filter { $0.dpd >= 31 && $0.dpd < 61  && !$0.isNPA } }
    var bucket90: [OverdueLoan] { overdueLoans.filter { $0.dpd >= 61 && !$0.isNPA } }
    var npaLoans:  [OverdueLoan] { overdueLoans.filter { $0.isNPA } }

    var totalOutstanding: Double { overdueLoans.map { $0.outstanding }.reduce(0, +) }

    // MARK: - Load

    func loadData() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.overdueLoans = Self.mockOverdueLoans()
            self.agents       = Self.mockAgents()
            if self.selectedLoan == nil { self.selectedLoan = self.overdueLoans.first }
            self.isLoading    = false
        }
    }

    // MARK: - Actions

    func beginSettlement(_ loan: OverdueLoan) {
        selectedLoan = loan
        settlementNote = ""
        showSettlementSheet = true
    }

    func confirmSettlement() {
        guard let loan = selectedLoan else { return }
        if let idx = overdueLoans.firstIndex(where: { $0.id == loan.id }) {
            overdueLoans[idx].settlementOffered = true
        }
        actionMessage = "Settlement offered for \(loan.borrowerName)"
        showActionAlert = true
        showSettlementSheet = false
    }

    func markNPA(_ loan: OverdueLoan) {
        if let idx = overdueLoans.firstIndex(where: { $0.id == loan.id }) {
            withAnimation { overdueLoans[idx].isNPA = true }
        }
        actionMessage = "\(loan.borrowerName) classified as NPA"
        showActionAlert = true
    }

    func assignAgent(_ agentName: String, to loan: OverdueLoan) {
        if let idx = overdueLoans.firstIndex(where: { $0.id == loan.id }) {
            overdueLoans[idx].assignedAgent = agentName
        }
        actionMessage = "Assigned \(agentName) to \(loan.borrowerName)"
        showActionAlert = true
    }

    // MARK: - Mock Data

    static func mockOverdueLoans() -> [OverdueLoan] {
        [
            OverdueLoan(id: "OL-001", applicationId: "APP-2024-006",
                        borrowerName: "Meera Joshi", loanType: "Personal Loan",
                        emi: 2400, dpd: 18, outstanding: 285000,
                        assignedAgent: "Rajiv Kumar", isNPA: false, settlementOffered: false),
            OverdueLoan(id: "OL-002", applicationId: "APP-2024-003",
                        borrowerName: "Vikram Desai", loanType: "Home Loan",
                        emi: 64000, dpd: 45, outstanding: 7650000,
                        assignedAgent: "Priya Singh", isNPA: false, settlementOffered: false),
            OverdueLoan(id: "OL-003", applicationId: "APP-2024-005",
                        borrowerName: "Suresh Nair", loanType: "Business Loan",
                        emi: 40000, dpd: 92, outstanding: 4800000,
                        assignedAgent: "Unassigned", isNPA: false, settlementOffered: true),
            OverdueLoan(id: "OL-004", applicationId: "APP-2024-010",
                        borrowerName: "Divya Krishnan", loanType: "Home Loan",
                        emi: 36000, dpd: 120, outstanding: 4320000,
                        assignedAgent: "Rajiv Kumar", isNPA: true, settlementOffered: false)
        ]
    }

    static func mockAgents() -> [RecoveryAgent] {
        [
            RecoveryAgent(id: "AGT-001", name: "Rajiv Kumar",   assignedCount: 2, recoveryRate: 0.72),
            RecoveryAgent(id: "AGT-002", name: "Priya Singh",   assignedCount: 1, recoveryRate: 0.85),
            RecoveryAgent(id: "AGT-003", name: "Anand Verma",   assignedCount: 0, recoveryRate: 0.68)
        ]
    }

    func mockEMIRecords(for loan: OverdueLoan) -> [EMIRecord] {
        let cal = Calendar.current
        return [
            EMIRecord(id: "EMI-1", month: "Jan 2025",
                      dueDate: cal.date(byAdding: .month, value: -4, to: Date())!,
                      amount: loan.emi, paid: true,
                      paidDate: cal.date(byAdding: .month, value: -4, to: Date())!),
            EMIRecord(id: "EMI-2", month: "Feb 2025",
                      dueDate: cal.date(byAdding: .month, value: -3, to: Date())!,
                      amount: loan.emi, paid: true,
                      paidDate: cal.date(byAdding: .month, value: -3, to: Date())!),
            EMIRecord(id: "EMI-3", month: "Mar 2025",
                      dueDate: cal.date(byAdding: .month, value: -2, to: Date())!,
                      amount: loan.emi, paid: false, paidDate: nil),
            EMIRecord(id: "EMI-4", month: "Apr 2025",
                      dueDate: cal.date(byAdding: .month, value: -1, to: Date())!,
                      amount: loan.emi, paid: false, paidDate: nil)
        ]
    }
}
