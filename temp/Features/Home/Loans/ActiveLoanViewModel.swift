import Foundation
import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class ActiveLoanViewModel: ObservableObject {
    @Published var activeLoan: ActiveLoan? = nil
    /// All active loans (populated by fetchAllLoans; single-loan fetches leave this empty).
    @Published var allLoans: [ActiveLoan] = []
    @Published var emiSchedule: [EmiScheduleItem] = []
    @Published var payments: [LoanPayment] = []
    /// Maps emiScheduleItem.id → loanId – populated by fetchAllLoans().
    @Published var loanIdByEmiId: [String: String] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    var upcomingEMIs: [EmiScheduleItem] {
        emiSchedule
            .filter { $0.status == .upcoming || $0.status == .overdue }
            .sorted { lhs, rhs in
                // Sort overdue first, then by due date ascending
                if lhs.status != rhs.status {
                    return lhs.status == .overdue
                }
                return lhs.dueDate < rhs.dueDate
            }
    }

    var overdueEMIs: [EmiScheduleItem] {
        emiSchedule.filter { $0.status == .overdue }
    }

    var repaymentProgress: Double {
        guard !emiSchedule.isEmpty else { return 0 }
        let paid = emiSchedule.filter { $0.status == .paid }.count
        return Double(paid) / Double(emiSchedule.count)
    }

    var outstandingBalanceFormatted: String {
        guard let loan = activeLoan else { return "—" }
        return formatCurrency(loan.outstandingBalance)
    }

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func fetchAll(applicationId: String) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let loan = try await service.getLoan(loanId: nil, applicationId: applicationId)
                activeLoan = loan
                async let emi = service.listEmiSchedule(loanId: loan.id)
                async let pay = service.listPayments(loanId: loan.id)
                (emiSchedule, payments) = try await (emi, pay)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load loan"
            }
            isLoading = false
        }
    }

    /// Used when navigating directly from a loanId (e.g. OverdueDetailsView)
    func fetchAllByLoanId(loanId: String) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let loan = try await service.getLoan(loanId: loanId, applicationId: nil)
                activeLoan = loan
                async let emi = service.listEmiSchedule(loanId: loan.id)
                async let pay = service.listPayments(loanId: loan.id)
                (emiSchedule, payments) = try await (emi, pay)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load loan"
            }
            isLoading = false
        }
    }

    /// Loads ALL active loans concurrently and merges every loan's EMI schedule and
    /// payment history into the shared published arrays.  Use this for screens that
    /// must show data across all of the borrower's loans (Upcoming / History tabs).
    func fetchAllLoans() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let loans = try await service.listLoans(limit: 100, offset: 0)
                allLoans = loans
                activeLoan = loans.first  // Keep a convenience reference to the most-recent loan

                // Fetch every loan's schedule + payments concurrently
                try await withThrowingTaskGroup(of: (String, [EmiScheduleItem], [LoanPayment]).self) { group in
                    for loan in loans {
                        group.addTask { [service] in
                            async let emi = service.listEmiSchedule(loanId: loan.id)
                            async let pay = service.listPayments(loanId: loan.id)
                            let (e, p) = try await (emi, pay)
                            return (loan.id, e, p)
                        }
                    }
                    var mergedEMI: [EmiScheduleItem] = []
                    var mergedPay: [LoanPayment] = []
                    var emiLoanMap: [String: String] = [:]
                    for try await (loanId, emi, pay) in group {
                        for item in emi { emiLoanMap[item.id] = loanId }
                        mergedEMI.append(contentsOf: emi)
                        mergedPay.append(contentsOf: pay)
                    }
                    // Sort merged results
                    emiSchedule    = mergedEMI.sorted { $0.dueDate < $1.dueDate }
                    payments       = mergedPay.sorted { $0.createdAt > $1.createdAt }
                    loanIdByEmiId  = emiLoanMap
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load repayments"
            }
            isLoading = false
        }
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let num = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? raw
    }
}
