import SwiftUI
import Combine

struct LoanAnalyticsSnapshot {
    let principal: Double
    let interest: Double
    let fees: Double
    let totalPayable: Double
    let monthlyEMIOutflow: Double
    let totalPaid: Double
    let outstandingBalance: Double
    let activeLoanCount: Int
    let upcomingEMICount: Int
    let overdueEMICount: Int
    let averageInterestRate: Double
    let totalInstallments: Int
}

@MainActor
@available(iOS 18.0, *)
final class LoanCostViewModel: ObservableObject {
    @Published private(set) var snapshot: LoanAnalyticsSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func fetchAnalytics() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loans = try await service.listLoans(limit: 100, offset: 0)
            guard !loans.isEmpty else {
                snapshot = nil
                errorMessage = "No disbursed loan data is available yet."
                return
            }

            let applications = try await service.listLoanApplications(limit: 100, offset: 0)
            let applicationsById = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })

            let productIDs = Set(loans.compactMap { loan in
                applicationsById[loan.applicationId]?.loanProductId
            })
            let productsById = try await fetchProducts(productIDs: productIDs)
            let schedulesByLoanId = try await fetchSchedules(loans: loans)
            let paymentsByLoanId = try await fetchPayments(loans: loans)

            let principal = loans.sum { Double($0.principalAmount) ?? 0 }
            let monthlyEMIOutflow = loans
                .filter { $0.status == .active || $0.status == .npa }
                .sum { Double($0.emiAmount) ?? 0 }
            let outstandingBalance = loans
                .filter { $0.status == .active || $0.status == .npa }
                .sum { Double($0.outstandingBalance) ?? 0 }
            let totalPaid = paymentsByLoanId.values
                .flatMap { $0 }
                .filter { $0.status == .success }
                .sum { Double($0.amount) ?? 0 }

            let totalInstallments = schedulesByLoanId.values.reduce(0) { $0 + $1.count }
            let upcomingEMICount = schedulesByLoanId.values
                .flatMap { $0 }
                .filter { $0.status == .upcoming }
                .count
            let overdueEMICount = schedulesByLoanId.values
                .flatMap { $0 }
                .filter { $0.status == .overdue }
                .count

            let interest = loans.sum { loan in
                let principalAmount = Double(loan.principalAmount) ?? 0
                let schedule = schedulesByLoanId[loan.id] ?? []
                let scheduledAmount = schedule.sum { Double($0.emiAmount) ?? 0 }
                if scheduledAmount > 0 {
                    return max(0, scheduledAmount - principalAmount)
                }

                let tenure = applicationsById[loan.applicationId]?.tenureMonths ?? 0
                let emiAmount = Double(loan.emiAmount) ?? 0
                guard tenure > 0, emiAmount > 0 else { return 0 }
                return max(0, (emiAmount * Double(tenure)) - principalAmount)
            }

            let fees = loans.sum { loan in
                guard
                    let application = applicationsById[loan.applicationId],
                    let product = productsById[application.loanProductId]
                else {
                    return 0
                }
                return Self.processingFees(for: product, principal: Double(loan.principalAmount) ?? 0)
            }

            let averageInterestRate = {
                let rates = loans.compactMap { Double($0.interestRate) }
                guard !rates.isEmpty else { return 0 }
                return Int(rates.reduce(0, +) / Double(rates.count))
            }()

            snapshot = LoanAnalyticsSnapshot(
                principal: principal,
                interest: interest,
                fees: fees,
                totalPayable: principal + interest + fees,
                monthlyEMIOutflow: monthlyEMIOutflow,
                totalPaid: totalPaid,
                outstandingBalance: outstandingBalance,
                activeLoanCount: loans.filter { $0.status == .active || $0.status == .npa }.count,
                upcomingEMICount: upcomingEMICount,
                overdueEMICount: overdueEMICount,
                averageInterestRate: Double(averageInterestRate),
                totalInstallments: totalInstallments
            )
        } catch {
            snapshot = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load analytics."
        }
    }

    private func fetchProducts(productIDs: Set<String>) async throws -> [String: LoanProduct] {
        try await withThrowingTaskGroup(of: (String, LoanProduct).self) { group in
            for productID in productIDs where !productID.isEmpty {
                group.addTask { [service] in
                    let product = try await service.getLoanProduct(productId: productID)
                    return (productID, product)
                }
            }

            var products: [String: LoanProduct] = [:]
            for try await (productID, product) in group {
                products[productID] = product
            }
            return products
        }
    }

    private func fetchSchedules(loans: [ActiveLoan]) async throws -> [String: [EmiScheduleItem]] {
        try await withThrowingTaskGroup(of: (String, [EmiScheduleItem]).self) { group in
            for loan in loans {
                group.addTask { [service] in
                    let schedule = try await service.listEmiSchedule(loanId: loan.id)
                    return (loan.id, schedule)
                }
            }

            var schedules: [String: [EmiScheduleItem]] = [:]
            for try await (loanID, schedule) in group {
                schedules[loanID] = schedule
            }
            return schedules
        }
    }

    private func fetchPayments(loans: [ActiveLoan]) async throws -> [String: [LoanPayment]] {
        try await withThrowingTaskGroup(of: (String, [LoanPayment]).self) { group in
            for loan in loans {
                group.addTask { [service] in
                    let payments = try await service.listPayments(loanId: loan.id)
                    return (loan.id, payments)
                }
            }

            var payments: [String: [LoanPayment]] = [:]
            for try await (loanID, loanPayments) in group {
                payments[loanID] = loanPayments
            }
            return payments
        }
    }

    private static func processingFees(for product: LoanProduct, principal: Double) -> Double {
        product.fees
            .filter { $0.type == .processing }
            .sum { fee in
                let value = Double(fee.value) ?? 0
                switch fee.calcMethod {
                case .flat:
                    return value
                case .percentage:
                    return principal * value / 100
                case .unspecified:
                    return 0
                }
            }
    }
}

@available(iOS 18.0, *)
struct LoanCostBreakdownView: View {
    @StateObject private var viewModel = LoanCostViewModel()
    @State private var animateChart = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if viewModel.isLoading && viewModel.snapshot == nil {
                    ProgressView("Loading live analytics...")
                        .padding(.top, 60)
                } else if let snapshot = viewModel.snapshot {
                    overviewCards(snapshot)
                    donutCard(snapshot)
                    breakdownCard(snapshot)
                    emiCard(snapshot)
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 40)
        }
        .background(DS.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchAnalytics()
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateChart = true
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Analytics")
                .font(AppFonts.rounded(28, weight: .bold))
                .foregroundColor(DS.textPrimary)
            Text("Live borrower portfolio insights from your loan backend")
                .font(AppFonts.rounded(14))
                .foregroundColor(DS.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func overviewCards(_ snapshot: LoanAnalyticsSnapshot) -> some View {
        HStack(spacing: 12) {
            AnalyticsStatCard(
                title: "Outstanding",
                value: currency(snapshot.outstandingBalance),
                subtitle: "\(snapshot.activeLoanCount) live loan\(snapshot.activeLoanCount == 1 ? "" : "s")",
                accent: DS.primary,
                tint: DS.primaryLight
            )
            AnalyticsStatCard(
                title: "Paid So Far",
                value: currency(snapshot.totalPaid),
                subtitle: snapshot.overdueEMICount == 0 ? "On-track repayments" : "\(snapshot.overdueEMICount) overdue EMI\(snapshot.overdueEMICount == 1 ? "" : "s")",
                accent: snapshot.overdueEMICount == 0 ? Color(hex: "#00C48C") : DS.danger,
                tint: snapshot.overdueEMICount == 0 ? Color(hex: "#00C48C").opacity(0.12) : DS.danger.opacity(0.10)
            )
        }
        .padding(.horizontal, 20)
    }

    private func donutCard(_ snapshot: LoanAnalyticsSnapshot) -> some View {
        VStack(spacing: 20) {
            ImprovedDonutChartView(
                principal: snapshot.principal,
                interest: snapshot.interest,
                fees: snapshot.fees,
                total: snapshot.totalPayable,
                animate: animateChart
            )
            .frame(height: 200)

            HStack(spacing: 0) {
                LegendItem(color: DS.primary, label: "Principal", tint: DS.primaryLight)
                Spacer()
                LegendItem(color: DS.warning, label: "Interest", tint: DS.warning.opacity(0.12))
                Spacer()
                LegendItem(color: DS.danger, label: "Fees", tint: DS.danger.opacity(0.10))
            }
            .padding(.horizontal, 12)
        }
        .padding(20)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DS.textPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private func breakdownCard(_ snapshot: LoanAnalyticsSnapshot) -> some View {
        VStack(spacing: 0) {
            EnhancedBreakdownRow(
                title: "Principal Disbursed",
                subtitle: "Live total across disbursed loans",
                amount: snapshot.principal,
                color: DS.primary,
                tint: DS.primaryLight,
                percent: snapshot.principal / max(snapshot.totalPayable, 1)
            )
            RowDivider()

            EnhancedBreakdownRow(
                title: "Projected Interest",
                subtitle: String(format: "%.1f%% average rate · %d installments", snapshot.averageInterestRate, snapshot.totalInstallments),
                amount: snapshot.interest,
                color: DS.warning,
                tint: DS.warning.opacity(0.12),
                percent: snapshot.interest / max(snapshot.totalPayable, 1)
            )
            RowDivider()

            EnhancedBreakdownRow(
                title: "Processing Fees",
                subtitle: "Calculated from loan product fee rules",
                amount: snapshot.fees,
                color: DS.danger,
                tint: DS.danger.opacity(0.10),
                percent: snapshot.fees / max(snapshot.totalPayable, 1)
            )

            Divider()
                .padding(.vertical, 4)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Scheduled Outflow")
                        .font(AppFonts.rounded(15, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                    Text("Principal + Interest + Fees")
                        .font(AppFonts.rounded(12))
                        .foregroundColor(DS.textSecondary)
                }
                Spacer()
                Text(currency(snapshot.totalPayable))
                    .font(AppFonts.rounded(18, weight: .bold))
                    .foregroundColor(DS.textPrimary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(DS.primaryLight.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DS.textPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private func emiCard(_ snapshot: LoanAnalyticsSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly EMI Outflow")
                    .font(AppFonts.rounded(12))
                    .foregroundColor(DS.textSecondary)
                Text(currency(snapshot.monthlyEMIOutflow))
                    .font(AppFonts.rounded(26, weight: .bold))
                    .foregroundColor(DS.primary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(snapshot.upcomingEMICount)")
                    .font(AppFonts.rounded(22, weight: .bold))
                    .foregroundColor(DS.primary)
                Text("upcoming")
                    .font(AppFonts.rounded(11))
                    .foregroundColor(DS.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DS.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DS.textPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(DS.primary)
            Text(viewModel.errorMessage ?? "Analytics are not available right now.")
                .font(AppFonts.rounded(14))
                .foregroundColor(DS.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.top, 40)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}

private struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let accent: Color
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFonts.rounded(12, weight: .medium))
                .foregroundColor(DS.textSecondary)
            Text(value)
                .font(AppFonts.rounded(22, weight: .bold))
                .foregroundColor(DS.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(AppFonts.rounded(11, weight: .medium))
                .foregroundColor(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tint)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: DS.textPrimary.opacity(0.05), radius: 10, x: 0, y: 3)
    }
}

// MARK: - Improved Donut Chart
struct ImprovedDonutChartView: View {
    let principal: Double
    let interest: Double
    let fees: Double
    let total: Double
    let animate: Bool

    private var principalFrac: Double { total > 0 ? principal / total : 0 }
    private var interestFrac: Double { total > 0 ? interest / total : 0 }
    private var feesFrac: Double { total > 0 ? fees / total : 0 }

    private let gap: Double = 0.008

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.border, lineWidth: 26)

            Circle()
                .trim(from: gap / 2, to: principalEnd)
                .stroke(
                    DS.gradient,
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: animate)

            Circle()
                .trim(
                    from: interestStart,
                    to: interestEnd
                )
                .stroke(
                    LinearGradient(
                        colors: [DS.warning, DS.warning.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0).delay(0.1), value: animate)

            Circle()
                .trim(
                    from: feesStart,
                    to: feesEnd
                )
                .stroke(
                    DS.dangerGradient,
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0).delay(0.2), value: animate)

            VStack(spacing: 2) {
                Text("Scheduled Total")
                    .font(AppFonts.rounded(11, weight: .medium))
                    .foregroundColor(DS.textSecondary)
                Text(currencyCompact(total))
                    .font(AppFonts.rounded(22, weight: .bold))
                    .foregroundColor(DS.textPrimary)
            }
        }
        .padding(16)
    }

    private var principalEnd: CGFloat {
        CGFloat(animate ? max(principalFrac - gap / 2, 0) : 0)
    }

    private var interestStart: CGFloat {
        CGFloat(min(principalFrac + gap / 2, 1))
    }

    private var interestEnd: CGFloat {
        guard animate, interestFrac > 0 else { return CGFloat(principalFrac) }
        return CGFloat(min(principalFrac + interestFrac - gap / 2, 1))
    }

    private var feesStart: CGFloat {
        CGFloat(min(principalFrac + interestFrac + gap / 2, 1))
    }

    private var feesEnd: CGFloat {
        guard animate, feesFrac > 0 else { return CGFloat(principalFrac + interestFrac) }
        return CGFloat(min(principalFrac + interestFrac + feesFrac - gap / 2, 1))
    }

    private func currencyCompact(_ value: Double) -> String {
        "₹\(value.formatted(.number.notation(.compactName).precision(.fractionLength(1))))"
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(AppFonts.rounded(12, weight: .medium))
                .foregroundColor(DS.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Enhanced Breakdown Row
struct EnhancedBreakdownRow: View {
    let title: String
    let subtitle: String
    let amount: Double
    let color: Color
    let tint: Color
    let percent: Double

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFonts.rounded(14, weight: .semibold))
                    .foregroundColor(DS.textPrimary)
                Text(subtitle)
                    .font(AppFonts.rounded(11))
                    .foregroundColor(DS.textSecondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DS.border)
                            .frame(height: 3)
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(min(max(percent, 0), 1)), height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(AppFonts.rounded(15, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                Text(String(format: "%.1f%%", percent * 100))
                    .font(AppFonts.rounded(11, weight: .medium))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tint)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
    }
}

// MARK: - Divider Helper
struct RowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 20)
    }
}

private extension Sequence {
    func sum(_ transform: (Element) -> Double) -> Double {
        reduce(0) { $0 + transform($1) }
    }
}

// MARK: - Preview
struct LoanCostBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            if #available(iOS 18.0, *) {
                LoanCostBreakdownView()
            } else {
                Text("Requires iOS 18")
            }
        }
    }
}
