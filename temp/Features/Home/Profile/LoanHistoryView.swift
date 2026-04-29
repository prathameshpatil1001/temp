import SwiftUI
import Combine

struct LoanHistoryView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = LoanHistoryViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LoanHistoryHeader {
                    router.pop()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if viewModel.isLoading && viewModel.closedLoans.isEmpty {
                    ProgressView()
                        .padding(.top, 16)
                } else if let errorMessage = viewModel.errorMessage, viewModel.closedLoans.isEmpty {
                    LoanHistoryStateCard(
                        title: "Loan history unavailable",
                        message: errorMessage
                    )
                    .padding(.horizontal, 20)
                } else if viewModel.closedLoans.isEmpty {
                    LoanHistoryStateCard(
                        title: "No closed loans yet",
                        message: "Completed loans will appear here once a loan is fully repaid and marked closed."
                    )
                    .padding(.horizontal, 20)
                } else {
                    ForEach(viewModel.closedLoans) { loan in
                        ClosedLoanCard(loan: loan)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.fetchLoanHistory()
        }
    }
}

private struct LoanHistoryHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Loan History")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }
}

private struct ClosedLoanCard: View {
    let loan: ClosedLoanHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.title)
                        .font(.headline)
                    if let closedOn = loan.closedOnText {
                        Text("Closed on \(closedOn)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Loan closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("Closed")
                    .font(.caption).bold()
                    .foregroundColor(Color(hex: "#00C48C"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#00C48C").opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Total Amount").font(.caption).foregroundColor(.secondary)
                    Text(formatLoanHistoryCurrency(loan.totalAmount)).font(.subheadline).bold()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Tenure").font(.caption).foregroundColor(.secondary)
                    Text("\(loan.tenureMonths) Months").font(.subheadline).bold()
                }
            }

            Divider()

            Button {
                // Wire this to the NDC endpoint once the backend provides the document download.
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Download No Dues Certificate")
                }
                .font(.subheadline).bold()
                .foregroundColor(.mainBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DS.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

private struct LoanHistoryStateCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

private struct ClosedLoanHistoryItem: Identifiable {
    let id: String
    let title: String
    let totalAmount: Double
    let tenureMonths: Int
    let closedOnText: String?
}

@MainActor
@available(iOS 18.0, *)
private final class LoanHistoryViewModel: ObservableObject {
    @Published var closedLoans: [ClosedLoanHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func fetchLoanHistory() {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                async let applicationsTask = service.listLoanApplications(limit: 100, offset: 0)
                async let loansTask = service.listLoans(limit: 100, offset: 0)

                let (applications, loans) = try await (applicationsTask, loansTask)
                let applicationsById = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
                let schedules = try await loadSchedules(for: loans)
                let closedLoans = loans.filter { loan in
                    isLoanCompleted(loan, schedule: schedules[loan.id] ?? [])
                }
                let closureDates = buildClosureDates(from: schedules, for: closedLoans)

                self.closedLoans = closedLoans.map { loan in
                    let application = applicationsById[loan.applicationId]
                    return ClosedLoanHistoryItem(
                        id: loan.id,
                        title: loanTitle(for: application),
                        totalAmount: Double(loan.principalAmount) ?? Double(application?.requestedAmount ?? "") ?? 0,
                        tenureMonths: application?.tenureMonths ?? 0,
                        closedOnText: closureDates[loan.id].map(formatDate)
                    )
                }
                .sorted {
                    let lhsDate = closureDates[$0.id] ?? .distantPast
                    let rhsDate = closureDates[$1.id] ?? .distantPast
                    return lhsDate > rhsDate
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load loan history."
                closedLoans = []
            }
        }
    }

    private func loadSchedules(for loans: [ActiveLoan]) async throws -> [String: [EmiScheduleItem]] {
        try await withThrowingTaskGroup(of: (String, [EmiScheduleItem]).self) { group in
            for loan in loans {
                group.addTask { [service] in
                    let items = try await service.listEmiSchedule(loanId: loan.id)
                    return (loan.id, items)
                }
            }

            var schedules: [String: [EmiScheduleItem]] = [:]
            for try await (loanId, items) in group {
                schedules[loanId] = items
            }
            return schedules
        }
    }

    private func buildClosureDates(
        from schedules: [String: [EmiScheduleItem]],
        for loans: [ActiveLoan]
    ) -> [String: Date] {
        var result: [String: Date] = [:]
        for loan in loans {
            let latestDate = (schedules[loan.id] ?? [])
                .map { parseLoanHistoryDate($0.dueDate) }
                .max()
            if let latestDate {
                result[loan.id] = latestDate
            }
        }
        return result
    }

    private func isLoanCompleted(_ loan: ActiveLoan, schedule: [EmiScheduleItem]) -> Bool {
        if loan.status == .closed {
            return true
        }

        let outstanding = Double(loan.outstandingBalance) ?? .greatestFiniteMagnitude
        if outstanding <= 0.01 {
            return true
        }

        if !schedule.isEmpty && schedule.allSatisfy({ $0.status == .paid }) {
            return true
        }

        return false
    }

    private func loanTitle(for application: BorrowerLoanApplication?) -> String {
        guard let application else { return "Closed Loan" }
        return application.loanProductName.isEmpty ? "Closed Loan" : application.loanProductName
    }
    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private func parseLoanHistoryDate(_ raw: String) -> Date {
    if let date = ISO8601DateFormatter().date(from: raw) {
        return date
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: raw) ?? .distantPast
}

private func formatLoanHistoryCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_IN")
    formatter.numberStyle = .currency
    formatter.currencySymbol = "₹"
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
}
