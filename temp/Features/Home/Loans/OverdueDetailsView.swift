import SwiftUI

struct OverdueDetailsView: View {
    @EnvironmentObject var router: AppRouter
    
    let missedEMI: Double = 14200
    let lateFee: Double = 500
    var totalOverdue: Double { missedEMI + lateFee }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Alert Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.alertRed)
                    Text("Action Required")
                        .font(.title2).bold()
                    Text("You have a missed payment for March 2026. Please clear your dues immediately to avoid further impact on your credit score.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Breakdown Box
                VStack(spacing: 0) {
                    HStack {
                        Text("Missed EMI Amount")
                            .font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        Text("₹\(missedEMI.formatted(.number.grouping(.automatic)))")
                            .font(.subheadline).bold()
                    }
                    .padding(20)
                    
                    Divider().padding(.leading, 20)
                    
                    HStack {
                        Text("Late Payment Penalty")
                            .font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        Text("+ ₹\(lateFee.formatted(.number.grouping(.automatic)))")
                            .font(.subheadline).bold()
                            .foregroundColor(.alertRed)
                    }
                    .padding(20)
                    
                    Divider()
                    
                    HStack {
                        Text("Total Overdue")
                            .font(.headline)
                        Spacer()
                        Text("₹\(totalOverdue.formatted(.number.grouping(.automatic)))")
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
                
                // Payment Button
                Button {
                    router.push(.paymentCheckout(amount: totalOverdue))
                } label: {
                    Text("Pay ₹\(totalOverdue.formatted(.number.grouping(.automatic))) Now")
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
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Overdue Payment")
        .navigationBarTitleDisplayMode(.inline)
    }
}
