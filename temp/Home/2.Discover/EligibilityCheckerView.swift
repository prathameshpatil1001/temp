import SwiftUI

struct EligibilityCheckerView: View {
    let loan: LoanProduct
    @EnvironmentObject var router: Router
    
    @State private var monthlyIncome: Double = 50000
    @State private var hasExistingLoans = false
    @State private var showResult = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Eligibility Check")
                            .font(.largeTitle).bold()
                        Text("Let's see if you qualify for the \(loan.title).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Form
                    VStack(alignment: .leading, spacing: 24) {
                        // Income Slider
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Monthly Income")
                                    .font(.headline)
                                Spacer()
                                Text("₹\(monthlyIncome.formatted(.number.grouping(.automatic)))")
                                    .font(.title3).bold()
                                    .foregroundColor(.mainBlue)
                            }
                            
                            Slider(value: $monthlyIncome, in: 20000...200000, step: 5000)
                                .accentColor(.mainBlue)
                        }
                        
                        Divider()
                        
                        // Existing Loans Toggle
                        Toggle("I have existing active loans or EMIs", isOn: $hasExistingLoans)
                            .font(.headline)
                            .tint(.mainBlue)
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    // Result Banner
                    if showResult {
                        HStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundColor(Color(hex: "#00C48C"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("You're Eligible!")
                                    .font(.headline)
                                    .foregroundColor(Color(hex: "#00C48C"))
                                Text("Based on your inputs, you meet the preliminary criteria for this loan.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .background(Color(hex: "#00C48C").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#00C48C").opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer().frame(height: 100)
                }
            }
            
            // Sticky Bottom Button
            VStack {
                Divider()
                Button {
                    if showResult {
                        // FIX: Passed the 'loan' object into the route!
                        router.push(.startApplication(loan))
                    } else {
                        withAnimation { showResult = true }
                    }
                } label: {
                    Text(showResult ? "Proceed to Apply" : "Check Eligibility")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.mainBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
