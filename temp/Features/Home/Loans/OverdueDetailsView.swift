import SwiftUI

@available(iOS 18.0, *)
struct OverdueDetailsView: View {
    let loanId: String
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel = ActiveLoanViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                if viewModel.isLoading {
                    ProgressView("Loading overdue details…")
                        .padding(.top, 60)
                } else if viewModel.overdueEMIs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#00C48C"))
                        Text("No Overdue Payments")
                            .font(.title2).bold()
                        Text("You have no missed EMIs at this time.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 20)
                } else {
                    let overdueEMIs = viewModel.overdueEMIs
                    let totalAmount = overdueEMIs.compactMap { Double($0.emiAmount) }.reduce(0, +)

                    // Alert Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.alertRed)
                        Text("Action Required")
                            .font(.title2).bold()
                        Text("You have \(overdueEMIs.count) missed \(overdueEMIs.count == 1 ? "installment" : "installments"). Please clear your dues immediately to avoid further impact on your credit score.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                    // Breakdown per overdue EMI
                    VStack(spacing: 0) {
                        ForEach(Array(overdueEMIs.enumerated()), id: \.element.id) { idx, emi in
                            HStack {
                                Text("Installment #\(emi.installmentNumber) – Due \(emi.dueDate)")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                Text(formatAmount(emi.emiAmount))
                                    .font(.subheadline).bold()
                            }
                            .padding(20)
                            if idx < overdueEMIs.count - 1 {
                                Divider().padding(.leading, 20)
                            }
                        }

                        Divider()

                        HStack {
                            Text("Total Overdue")
                                .font(.headline)
                            Spacer()
                            Text(formatAmount(String(totalAmount)))
                                .font(.title3).bold()
                                .foregroundColor(.alertRed)
                        }
                        .padding(20)
                        .background(DS.danger.opacity(0.05))
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.danger.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // Note: late fee calculated by the bank
                    Text("Late payment penalty (if applicable) will be included by the bank at time of collection.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Pay the first overdue EMI
                    if let firstOverdue = overdueEMIs.first {
                        Button {
                            guard let amountDouble = Double(firstOverdue.emiAmount) else { return }
                            router.push(.paymentCheckout(
                                loanId: loanId,
                                emiScheduleId: firstOverdue.id,
                                amount: amountDouble
                            ))
                        } label: {
                            Text("Pay \(formatAmount(firstOverdue.emiAmount)) Now")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(DS.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Overdue Payment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.fetchAllByLoanId(loanId: loanId)
        }
    }

    private func formatAmount(_ raw: String) -> String {
        guard let num = Double(raw) else { return "₹\(raw)" }
        return "₹\(num.formatted(.number.grouping(.automatic)))"
    }
}
