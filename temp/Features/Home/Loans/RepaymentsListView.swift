import SwiftUI

@available(iOS 18.0, *)
struct RepaymentsListView: View {
    let loanId: String
    @State var selectedTab: Int // 0 = Upcoming, 1 = History
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = ActiveLoanViewModel()

    var body: some View {
        VStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Repayments")
                    .font(.largeTitle).bold()
                    .foregroundColor(.primary)
                Text("View your past and upcoming EMIs.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Custom Segmented Picker
            HStack(spacing: 0) {
                SegmentButton(title: "Upcoming", isSelected: selectedTab == 0) { selectedTab = 0 }
                SegmentButton(title: "History", isSelected: selectedTab == 1) { selectedTab = 1 }
            }
            .padding(4)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading…")
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if selectedTab == 0 {
                            let upcoming = viewModel.upcomingEMIs
                            if upcoming.isEmpty {
                                emptyState(message: "No upcoming EMIs")
                            } else {
                                ForEach(upcoming) { item in
                                    emiRow(item: item, isPaid: false)
                                }
                            }
                        } else {
                            let paid = viewModel.payments
                            if paid.isEmpty {
                                emptyState(message: "No payment history yet")
                            } else {
                                ForEach(paid) { payment in
                                    paymentRow(payment: payment)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.fetchAllLoans()
        }
    }

    @ViewBuilder
    private func emiRow(item: EmiScheduleItem, isPaid: Bool) -> some View {
        let (month, day) = splitDueDate(item.dueDate)
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(month)
                    .font(.caption2).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(isPaid ? Color(hex: "#00C48C") : DS.primary)
                Text(day)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
            }
            .frame(width: 50)
            .background(DS.primaryLight.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke((isPaid ? Color(hex: "#00C48C") : DS.primary).opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text("Installment #\(item.installmentNumber)")
                    .font(.headline)
                Text(item.dueDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(item.emiAmount))
                    .font(.subheadline).bold()
                if isPaid {
                    Text("Paid")
                        .font(.caption2).bold()
                        .foregroundColor(Color(hex: "#00C48C"))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(hex: "#00C48C").opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func paymentRow(payment: LoanPayment) -> some View {
        let (month, day) = splitDueDate(payment.createdAt)
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(month)
                    .font(.caption2).bold()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#00C48C"))
                Text(day)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
                    .padding(.vertical, 6)
            }
            .frame(width: 50)
            .background(DS.primaryLight.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: "#00C48C").opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text("Payment")
                    .font(.headline)
                Text("Ref: \(payment.externalTransactionId.prefix(12))…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatAmount(payment.amount))
                    .font(.subheadline).bold()
                statusBadge(payment.status)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func statusBadge(_ status: PaymentStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .success: return ("Paid", Color(hex: "#00C48C"))
            case .failed: return ("Failed", .alertRed)
            default: return ("Pending", .secondary)
            }
        }()
        Text(label)
            .font(.caption2).bold()
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func splitDueDate(_ raw: String) -> (String, String) {
        let parts = raw.components(separatedBy: "-")
        guard parts.count >= 3 else { return ("—", "—") }
        let monthNum = Int(parts[1]) ?? 1
        let months = ["", "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return (months[min(monthNum, 12)], parts[2].prefix(2).description)
    }

    private func formatAmount(_ raw: String) -> String {
        guard let num = Double(raw) else { return "₹\(raw)" }
        return "₹\(num.formatted(.number.grouping(.automatic)))"
    }
}

struct SegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline).bold()
                .foregroundColor(isSelected ? .mainBlue : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: isSelected ? .black.opacity(0.05) : .clear, radius: 2, x: 0, y: 1)
        }
    }
}
