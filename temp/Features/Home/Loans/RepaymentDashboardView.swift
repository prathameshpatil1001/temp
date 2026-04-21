import SwiftUI

struct RepaymentDashboardView: View {
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repayments")
                        .font(.largeTitle).bold()
                    Text("Manage your EMIs and payment schedules.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Overdue Warning Banner (Only visible if overdue)
                Button {
                    router.push(.overdueDetails)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Overdue Payment")
                                .font(.headline)
                            Text("You have 1 missed EMI. Avoid late fees.")
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
                
                // Upcoming EMI Card
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next EMI Due")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("20 Apr 2026")
                                .font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Amount")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("₹14,200")
                                .font(.title2).bold()
                                .foregroundColor(.mainBlue)
                        }
                    }
                    
                    Button {
                        router.push(.paymentCheckout(amount: 14200))
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
                
                // Links to Lists
                VStack(spacing: 16) {
                    RepaymentNavRow(title: "Upcoming Schedule", icon: "calendar.badge.clock") {
                        router.push(.repaymentsList(initialTab: 0))
                    }
                    Divider()
                    RepaymentNavRow(title: "Payment History", icon: "clock.arrow.circlepath") {
                        router.push(.repaymentsList(initialTab: 1))
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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

struct RepaymentDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        RepaymentDashboardView().environmentObject(AppRouter())
    }
}
