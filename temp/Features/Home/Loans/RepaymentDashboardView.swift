import SwiftUI

@available(iOS 18.0, *)
struct RepaymentDashboardView: View {
    let applicationId: String
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = ActiveLoanViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repayments")
                        .font(.largeTitle).bold()
                        .foregroundColor(.primary)
                    Text("Manage your EMIs and payment schedules.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if viewModel.isLoading {
                    ProgressView("Loading repayment data…")
                        .padding(.top, 40)
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if let loan = viewModel.activeLoan {
                    // Overdue Warning Banner – only shown if real overdues exist
                    if let overdueEMI = viewModel.overdueEMIs.first {
                        Button {
                            router.push(.overdueDetails(loanId: loan.id))
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Overdue Payment")
                                        .font(.headline)
                                    Text("Installment #\(overdueEMI.installmentNumber) missed. Avoid late fees.")
                                        .font(.subheadline)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.alertRed)
                            .padding(16)
                            .background(DS.danger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.danger.opacity(0.3), lineWidth: 1.5))
                        }
                        .padding(.horizontal, 20)
                    }

                    // Upcoming EMI Card
                    if let nextEMI = viewModel.upcomingEMIs.first {
                        VStack(spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Next EMI Due")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatDueDate(nextEMI.dueDate))
                                        .font(.headline)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Amount")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatAmount(nextEMI.emiAmount))
                                        .font(.title2).bold()
                                        .foregroundColor(.mainBlue)
                                }
                            }

                            Button {
                                guard let amountDouble = Double(nextEMI.emiAmount) else { return }
                                // Resolve the correct loanId for this EMI across all loans
                                let resolvedLoanId = viewModel.loanIdByEmiId[nextEMI.id]
                                    ?? viewModel.activeLoan?.id
                                    ?? ""
                                router.push(.paymentCheckout(
                                    loanId: resolvedLoanId,
                                    emiScheduleId: nextEMI.id,
                                    amount: amountDouble
                                ))
                            } label: {
                                Text("Pay Now")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(DS.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    } else {
                        // No upcoming EMIs
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.largeTitle)
                                .foregroundColor(Color(hex: "#00C48C"))
                            Text("No upcoming EMIs")
                                .font(.headline)
                            Text("You're all caught up.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }

                    // Links to EMI schedule and history
                    VStack(spacing: 16) {
                        RepaymentNavRow(title: "Upcoming Schedule", icon: "calendar.badge.clock") {
                            router.push(.repaymentsList(loanId: "", initialTab: 0))
                        }
                        Divider()
                        RepaymentNavRow(title: "Payment History", icon: "clock.arrow.circlepath") {
                            router.push(.repaymentsList(loanId: "", initialTab: 1))
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                } else {
                    // No active loan yet
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No active loan found")
                            .font(.headline)
                        Text("Repayment data is available once your loan is disbursed.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.fetchAllLoans()
        }
    }

    private func formatDueDate(_ raw: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: raw) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return raw
    }

    private func formatAmount(_ raw: String) -> String {
        guard let num = Double(raw) else { return "₹\(raw)" }
        return "₹\(num.formatted(.number.grouping(.automatic)))"
    }
}

struct RepaymentNavRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.mainBlue)
                    .frame(width: 30)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
    }
}
