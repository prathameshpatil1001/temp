import SwiftUI
import Combine

class LoanApplicationViewModel: ObservableObject {
    @Published var loanAmount: Double = 150000
    @Published var tenureMonths: Double = 24
    
    let minAmount: Double = 10000
    let maxAmount: Double = 500000
    let minTenure: Double = 6
    let maxTenure: Double = 60
    let interestRate: Double = 10.5
    
    var estimatedEMI: Double {
        let r = (interestRate / 12) / 100
        let n = tenureMonths
        let emi = (loanAmount * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
        return emi
    }
}

struct LoanApplicationView: View {
    let loan: LoanProduct
    @StateObject var viewModel = LoanApplicationViewModel()
    @EnvironmentObject var router: Router
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customize your loan")
                            .font(.largeTitle).bold()
                        Text("Select your desired amount and repayment tenure.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // 1. Amount Selection
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Loan Amount")
                                .font(.headline)
                            Spacer()
                            Text("₹\(viewModel.loanAmount.formatted(.number.grouping(.automatic)))")
                                .font(.title2).bold()
                                .foregroundColor(.mainBlue)
                        }
                        
                        Slider(value: $viewModel.loanAmount, in: viewModel.minAmount...viewModel.maxAmount, step: 10000)
                            .accentColor(.mainBlue)
                        
                        HStack {
                            Text("₹\(viewModel.minAmount.formatted(.number.notation(.compactName)))")
                            Spacer()
                            Text("₹\(viewModel.maxAmount.formatted(.number.notation(.compactName)))")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    
                    // 2. Tenure Selection
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Tenure (Months)")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(viewModel.tenureMonths)) Mos")
                                .font(.title2).bold()
                                .foregroundColor(.secondaryBlue)
                        }
                        
                        Slider(value: $viewModel.tenureMonths, in: viewModel.minTenure...viewModel.maxTenure, step: 3)
                            .accentColor(.secondaryBlue)
                        
                        HStack {
                            Text("\(Int(viewModel.minTenure)) Mos")
                            Spacer()
                            Text("\(Int(viewModel.maxTenure)) Mos")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    
                    // 3. Info Banner
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.mainBlue)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pre-approved at 10.5% p.a.")
                                .font(.subheadline).bold()
                            Text("No hidden charges. Instant disbursal upon final verification.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.lightBlue.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Space for sticky footer
            }
            
            // Sticky Footer with EMI and CTA
            VStack(spacing: 16) {
                Divider()
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated EMI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("₹\(viewModel.estimatedEMI.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                            .font(.title2).bold()
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        // Conditional Routing based on Loan Type
                        if loan.title == "Personal Loan" {
                            router.push(.documentUpload)
                        } else {
                            router.push(.submitConfirmation)
                        }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.mainBlue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background(Color(UIColor.systemBackground))
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LoanApplicationView(loan: LoanProduct(title: "Personal Loan", icon: "person", maxAmount: 500000, interestRate: "10.5%", minTenure: 6, maxTenure: 60, tags: []))
            .environmentObject(Router())
    }
}
