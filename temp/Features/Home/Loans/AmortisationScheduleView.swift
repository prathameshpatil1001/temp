import SwiftUI
import Charts
import Combine

struct AmortisationMonth: Identifiable, Hashable {
    let id: String
    let monthIndex: Int
    let date: Date
    let principalPaid: Double
    let interestPaid: Double
    let balance: Double
    let emiAmount: Double
    let status: EmiStatus

    var isPaid: Bool { status == .paid }
    var statusLabel: String { status.displayName }
}

@MainActor
@available(iOS 18.0, *)
final class AmortisationScheduleViewModel: ObservableObject {
    @Published private(set) var activeLoan: ActiveLoan?
    @Published private(set) var schedule: [AmortisationMonth] = []
    @Published var selectedMonth: AmortisationMonth?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLoan = false

    private let preferredLoanId: String?
    private let service: LoanServiceProtocol

    init(
        loanId: String? = nil,
        service: LoanServiceProtocol = ServiceContainer.loanService
    ) {
        self.preferredLoanId = loanId
        self.service = service
    }

    var groupedByYear: [(Int, [AmortisationMonth])] {
        let grouped = Dictionary(grouping: schedule) { month in
            Calendar.current.component(.year, from: month.date)
        }
        return grouped.keys.sorted().map { year in
            let items = grouped[year, default: []].sorted { $0.monthIndex < $1.monthIndex }
            return (year, items)
        }
    }

    var totalInterest: Double { schedule.reduce(0) { $0 + $1.interestPaid } }
    var totalPrincipal: Double { schedule.reduce(0) { $0 + $1.principalPaid } }
    var totalEmiCount: Int { schedule.count }

    var headerSubtitle: String {
        guard let first = schedule.first, let last = schedule.last, !schedule.isEmpty else {
            return "Your EMI schedule will appear once a loan is disbursed."
        }
        return "\(schedule.count) monthly payments from \(monthYearString(first.date)) to \(monthYearString(last.date))"
    }

    func load() async {
        await loadInternal()
    }

    private func loadInternal() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loan = try await resolveLoan()
            guard let loan else {
                hasLoan = false
                activeLoan = nil
                schedule = []
                selectedMonth = nil
                return
            }

            let scheduleItems = try await service.listEmiSchedule(loanId: loan.id)
            let amortisation = buildSchedule(for: loan, items: scheduleItems)

            hasLoan = true
            activeLoan = loan
            schedule = amortisation
            selectedMonth = amortisation.first
        } catch {
            hasLoan = false
            activeLoan = nil
            schedule = []
            selectedMonth = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load amortisation schedule."
        }
    }

    private func resolveLoan() async throws -> ActiveLoan? {
        if let preferredLoanId, !preferredLoanId.isEmpty {
            return try await service.getLoan(loanId: preferredLoanId, applicationId: nil)
        }

        let loans = try await service.listLoans(limit: 100, offset: 0)
        return loans.sorted { lhs, rhs in
            parseDate(lhs.createdAt) > parseDate(rhs.createdAt)
        }.first
    }

    private func buildSchedule(for loan: ActiveLoan, items: [EmiScheduleItem]) -> [AmortisationMonth] {
        let sortedItems = items.sorted { $0.installmentNumber < $1.installmentNumber }
        guard !sortedItems.isEmpty else { return [] }

        let monthlyRate = (Double(loan.interestRate) ?? 0) / 12 / 100
        var runningBalance = Double(loan.principalAmount) ?? 0

        return sortedItems.map { item in
            let emiAmount = Double(item.emiAmount) ?? 0
            let rawInterest = runningBalance * monthlyRate
            let interestPaid = max(rawInterest, 0)
            let rawPrincipal = emiAmount - interestPaid
            let principalPaid = min(max(rawPrincipal, 0), runningBalance)
            runningBalance = max(runningBalance - principalPaid, 0)

            return AmortisationMonth(
                id: item.id,
                monthIndex: item.installmentNumber,
                date: parseDate(item.dueDate),
                principalPaid: principalPaid,
                interestPaid: interestPaid,
                balance: runningBalance,
                emiAmount: emiAmount,
                status: item.status
            )
        }
    }

    private func parseDate(_ raw: String) -> Date {
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw) ?? .distantPast
    }

    private func monthYearString(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }
}

@available(iOS 18.0, *)
struct AmortisationScheduleView: View {
    let loanId: String?

    @StateObject private var viewModel: AmortisationScheduleViewModel
    @EnvironmentObject var router: AppRouter

    init(
        loanId: String? = nil,
        service: LoanServiceProtocol = ServiceContainer.loanService
    ) {
        self.loanId = loanId
        _viewModel = StateObject(wrappedValue: AmortisationScheduleViewModel(loanId: loanId, service: service))
    }

    // MARK: - Payment eligibility helpers

    /// Returns true only if:
    ///  • the month is not already paid
    ///  • every month with a lower installmentNumber is .paid
    private func canPay(_ month: AmortisationMonth) -> Bool {
        guard month.status != .paid else { return false }
        let prior = viewModel.schedule.filter { $0.monthIndex < month.monthIndex }
        return prior.allSatisfy { $0.status == .paid }
    }

    /// Human-readable reason why payment is blocked (nil when unblocked or already paid).
    private func blockedReason(for month: AmortisationMonth) -> String? {
        guard month.status != .paid else { return nil }
        let unpaidPrior = viewModel.schedule
            .filter { $0.monthIndex < month.monthIndex && $0.status != .paid }
            .sorted { $0.monthIndex < $1.monthIndex }
        guard let first = unpaidPrior.first else { return nil }
        return "EMI #\(first.monthIndex) must be paid before you can pay this EMI."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if viewModel.isLoading {
                    ProgressView("Loading EMI schedule…")
                        .padding(.top, 40)
                } else if let error = viewModel.errorMessage {
                    contentState(
                        icon: "wifi.exclamationmark",
                        title: "Couldn’t load schedule",
                        message: error
                    )
                } else if !viewModel.hasLoan {
                    contentState(
                        icon: "calendar.badge.exclamationmark",
                        title: "No amortisation schedule yet",
                        message: "This screen becomes available once your loan has been approved and disbursed."
                    )
                } else if viewModel.schedule.isEmpty {
                    contentState(
                        icon: "list.bullet.rectangle",
                        title: "Schedule not ready",
                        message: "We found your loan, but its EMI schedule is not available yet."
                    )
                } else {
                    summaryStrip

                    if let selectedMonth = viewModel.selectedMonth {
                        SelectedMonthCard(
                            month: selectedMonth,
                            totalEmiCount: viewModel.totalEmiCount,
                            canPay: canPay(selectedMonth),
                            blockedReason: blockedReason(for: selectedMonth),
                            onPay: {
                                guard let loanId = viewModel.activeLoan?.id else { return }
                                let amount = selectedMonth.emiAmount
                                router.push(.paymentCheckout(
                                    loanId: loanId,
                                    emiScheduleId: selectedMonth.id,
                                    amount: amount
                                ))
                            }
                        )
                        .padding(.horizontal, 20)
                    }

                    ForEach(viewModel.groupedByYear, id: \.0) { year, months in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(year))
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)

                            CalendarYearGrid(
                                months: months,
                                selectedMonth: $viewModel.selectedMonth
                            )
                            .padding(.horizontal, 20)
                        }
                    }

                    balanceChart
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amortisation Schedule")
                .font(.largeTitle).bold()
                .foregroundColor(.primary)
            Text(viewModel.headerSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            SummaryPill(
                label: "Total Principal",
                value: formatCompactCurrency(viewModel.totalPrincipal),
                color: .mainBlue
            )
            Divider().frame(height: 40)
            SummaryPill(
                label: "Total Interest",
                value: formatCompactCurrency(viewModel.totalInterest),
                color: .alertRed
            )
            Divider().frame(height: 40)
            SummaryPill(
                label: "EMI",
                value: formatCompactCurrency(Double(viewModel.activeLoan?.emiAmount ?? "") ?? 0),
                color: Color(hex: "#00C48C")
            )
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    private var balanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balance Over Time")
                .font(.headline)
                .padding(.horizontal, 20)

            Chart {
                ForEach(viewModel.schedule) { item in
                    AreaMark(
                        x: .value("Month", item.monthIndex),
                        y: .value("Balance", item.balance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.mainBlue.opacity(0.35), .lightBlue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Month", item.monthIndex),
                        y: .value("Balance", item.balance)
                    )
                    .foregroundStyle(DS.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: 3))
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompactCurrency(amount))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    private func contentState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
        .padding(.top, 40)
    }

    private func formatCompactCurrency(_ amount: Double) -> String {
        "₹\(amount.formatted(.number.notation(.compactName).precision(.fractionLength(2))))"
    }
}

private struct CalendarYearGrid: View {
    let months: [AmortisationMonth]
    @Binding var selectedMonth: AmortisationMonth?

    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private func calendarMonth(_ month: AmortisationMonth) -> String {
        let index = Calendar.current.component(.month, from: month.date) - 1
        return monthNames[max(0, min(index, monthNames.count - 1))]
    }

    private func principalFraction(_ month: AmortisationMonth) -> CGFloat {
        let total = month.principalPaid + month.interestPaid
        return total > 0 ? CGFloat(month.principalPaid / total) : 0
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(months) { month in
                let isSelected = selectedMonth?.id == month.id

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMonth = month
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(calendarMonth(month))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white : (month.isPaid ? .secondary : .primary))

                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 5)
                                .frame(width: 34, height: 34)

                            Circle()
                                .trim(from: 0, to: principalFraction(month))
                                .stroke(
                                    isSelected ? Color.white : DS.primary,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .frame(width: 34, height: 34)
                                .rotationEffect(.degrees(-90))

                            Circle()
                                .trim(from: principalFraction(month), to: 1)
                                .stroke(
                                    isSelected ? Color.white.opacity(0.5) : DS.danger.opacity(0.7),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .frame(width: 34, height: 34)
                                .rotationEffect(.degrees(-90))

                            if month.isPaid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isSelected ? .white : Color(hex: "#00C48C"))
                            }
                        }

                        Text("M\(month.monthIndex)")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? DS.primary : (month.isPaid ? DS.primaryLight.opacity(0.5) : Color.white))
                    )
                    .shadow(
                        color: isSelected ? DS.primary.opacity(0.3) : .black.opacity(0.04),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: 2
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SelectedMonthCard: View {
    let month: AmortisationMonth
    let totalEmiCount: Int
    var canPay: Bool = false
    var blockedReason: String? = nil
    var onPay: (() -> Void)? = nil

    private var dateString: String {
        month.date.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        VStack(spacing: 16) {
            // ── Header row ──────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.headline)
                    Text("EMI #\(month.monthIndex) of \(totalEmiCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Label(month.statusLabel, systemImage: statusIcon)
                    .font(.caption).bold()
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            // ── Principal / Interest bar ─────────────────────────
            GeometryReader { geometry in
                let total = month.principalPaid + month.interestPaid
                let principalWidth = total > 0 ? geometry.size.width * CGFloat(month.principalPaid / total) : 0

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DS.primary)
                        .frame(width: principalWidth, height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DS.danger.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 10, maxHeight: 10)
                }
            }
            .frame(height: 10)

            // ── Breakdown row ────────────────────────────────────
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(DS.primary).frame(width: 8, height: 8)
                        Text("Principal")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text(formatCurrency(month.principalPaid))
                        .font(.subheadline).bold().foregroundColor(.mainBlue)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("Total EMI")
                        .font(.caption).foregroundColor(.secondary)
                    Text(formatCurrency(month.emiAmount))
                        .font(.subheadline).bold()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Interest")
                            .font(.caption).foregroundColor(.secondary)
                        Circle().fill(DS.danger.opacity(0.7)).frame(width: 8, height: 8)
                    }
                    Text(formatCurrency(month.interestPaid))
                        .font(.subheadline).bold().foregroundColor(.alertRed)
                }
            }

            Divider()

            // ── Remaining balance row ────────────────────────────
            HStack {
                Text("Remaining Balance")
                    .font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Text(formatCurrency(month.balance))
                    .font(.subheadline).bold()
            }

            // ── Payment action section ───────────────────────────
            if month.status == .paid {
                // Already paid – show a success pill
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: "#00C48C"))
                    Text("This EMI has been paid")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "#00C48C"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(hex: "#00C48C").opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            } else if canPay {
                // Payable – show Pay EMI button
                Button {
                    onPay?()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.headline)
                        Text("Pay \(formatCurrency(month.emiAmount))")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [DS.primary, DS.primaryLight.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: DS.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)

            } else if let reason = blockedReason {
                // Blocked – show lock warning
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundColor(DS.danger)
                        .padding(.top, 1)
                    Text(reason)
                        .font(.subheadline)
                        .foregroundColor(DS.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(DS.danger.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DS.danger.opacity(0.25), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .animation(.spring(response: 0.3), value: canPay)
        .animation(.spring(response: 0.3), value: month.id)
    }

    private var statusIcon: String {
        switch month.status {
        case .paid:
            return "checkmark.seal.fill"
        case .overdue:
            return "exclamationmark.triangle.fill"
        default:
            return "clock.fill"
        }
    }

    private var statusColor: Color {
        switch month.status {
        case .paid:
            return Color(hex: "#00C48C")
        case .overdue:
            return .alertRed
        default:
            return .secondaryBlue
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        "₹\(amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))"
    }
}

private struct SummaryPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AmortisationScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            if #available(iOS 18.0, *) {
                AmortisationScheduleView()
            } else {
                Text("Requires iOS 18")
            }
        }
    }
}
