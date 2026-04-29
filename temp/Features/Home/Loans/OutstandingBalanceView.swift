import SwiftUI

@available(iOS 18.0, *)
struct OutstandingBalanceView: View {
    let loanId: String
    let applicationId: String
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ActiveLoanViewModel()
    
    @State private var errorMessage: String?
    
    let foreclosurePenaltyPercent: Double = 2.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Outstanding Balance")
                        .font(.largeTitle).bold()
                    Text("Detailed breakdown of your current dues.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if viewModel.isLoading {
                    ProgressView("Loading details...")
                        .padding(40)
                } else if let loan = viewModel.activeLoan {
                    content(for: loan)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    Text("No active loan found.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.fetchAllByLoanId(loanId: loanId)
        }
    }
    
    @ViewBuilder
    private func content(for loan: ActiveLoan) -> some View {
        let principalRemaining = Double(loan.outstandingBalance) ?? 0
        // Compute accrued interest dynamically if possible, else 0 for now
        let accruedInterest: Double = 0
        let lateFees: Double = viewModel.overdueEMIs.reduce(0) { $0 + (Double($1.emiAmount) ?? 0) * 0.05 } // Mock late fee logic
        
        let totalDuesToday = principalRemaining + accruedInterest + lateFees
        let foreclosurePenalty = principalRemaining * (foreclosurePenaltyPercent / 100.0)
        let foreclosureAmount = totalDuesToday + foreclosurePenalty
        
        // Current Dues Card
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Total Due As of Today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("₹\(totalDuesToday.formatted(.number.grouping(.automatic)))")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.alertRed)
            }
            .padding(24)
            
            Divider()
            
            VStack(spacing: 16) {
                OutstandingRow(title: "Principal Remaining", value: principalRemaining)
                OutstandingRow(title: "Interest Accrued (This month)", value: accruedInterest)
                OutstandingRow(title: "Late Fees & Charges", value: lateFees)
            }
            .padding(20)
            .background(DS.primaryLight.opacity(0.3))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
        
        // Foreclosure Box
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lock.open.fill")
                    .foregroundColor(.mainBlue)
                Text("Foreclosure Quote")
                    .font(.headline)
            }
            
            Text("If you wish to close this loan entirely today, a \(foreclosurePenaltyPercent, specifier: "%.1f")% foreclosure charge applies to the remaining principal.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Final Settlement Amount")
                    .font(.subheadline).bold()
                Spacer()
                Text("₹\(foreclosureAmount.formatted(.number.grouping(.automatic)))")
                    .font(.title3).bold()
                    .foregroundColor(.mainBlue)
            }
            .padding(16)
            .background(DS.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button {
                initiateForeclosure(amount: foreclosureAmount)
            } label: {
                Text("Proceed to Payment")
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
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
    
    private func initiateForeclosure(amount: Double) {
        // Redirect to payment checkout with an empty EMI schedule ID
        // The backend `InitiatePaymentRequest` supports optional emi_schedule_id
        router.push(.paymentCheckout(loanId: loanId, emiScheduleId: "", amount: amount))
    }
}

struct OutstandingRow: View {
    let title: String
    let value: Double
    var body: some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text("₹\(value.formatted(.number.grouping(.automatic)))").font(.subheadline).bold()
        }
    }
}
