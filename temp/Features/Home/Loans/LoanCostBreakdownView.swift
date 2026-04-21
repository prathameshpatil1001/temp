import SwiftUI
import Combine

// MARK: - View Model
class LoanCostViewModel: ObservableObject {
    @Published var principal: Double = 300000
    @Published var interestRate: Double = 10.5 // Yearly
    @Published var tenureMonths: Int = 36
    @Published var processingFeePercent: Double = 1.5
    
    // Calculations
    var totalInterest: Double {
        // Simple interest approximation for UI display
        let r = (interestRate / 12) / 100
        let n = Double(tenureMonths)
        let emi = (principal * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
        return (emi * n) - principal
    }
    
    var processingFee: Double {
        principal * (processingFeePercent / 100)
    }
    
    var totalPayable: Double {
        principal + totalInterest + processingFee
    }
    
    var emi: Double {
        (principal + totalInterest) / Double(tenureMonths)
    }
}

// MARK: - Main View
struct LoanCostBreakdownView: View {
    @StateObject var viewModel = LoanCostViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header (Updated to match AutoPay)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cost Breakdown")
                        .font(.largeTitle).bold()
                        .foregroundColor(.primary)
                    Text("Complete transparency on what you pay")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Donut Chart
                DonutChartView(
                    principal: viewModel.principal,
                    interest: viewModel.totalInterest,
                    fees: viewModel.processingFee,
                    total: viewModel.totalPayable
                )
                .frame(height: 220)
                .padding(.vertical, 20)
                
                // Detailed Breakdown List
                VStack(spacing: 0) {
                    BreakdownRow(title: "Principal Amount", amount: viewModel.principal, color: .mainBlue)
                    Divider().padding(.leading, 40)
                    
                    BreakdownRow(title: String(format: "Total Interest (%.1f%% p.a.)", viewModel.interestRate), amount: viewModel.totalInterest, color: .secondaryBlue)
                    Divider().padding(.leading, 40)
                    
                    BreakdownRow(title: String(format: "Processing Fee (%.1f%%)", viewModel.processingFeePercent), amount: viewModel.processingFee, color: .alertRed)
                    
                    Divider().padding(.vertical, 8)
                    
                    // Total Row
                    HStack {
                        Text("Total Amount Payable")
                            .font(.headline)
                        Spacer()
                        Text("₹\(viewModel.totalPayable.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                            .font(.title3).bold()
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(DS.primaryLight.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // EMI Highlight
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly EMI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("₹\(viewModel.emi.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                            .font(.title2).bold()
                            .foregroundColor(.mainBlue)
                    }
                    Spacer()
                    Text("For \(viewModel.tenureMonths) Months")
                        .font(.subheadline).bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DS.primaryLight)
                        .foregroundColor(.secondaryBlue)
                        .clipShape(Capsule())
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subcomponents
struct BreakdownRow: View {
    let title: String
    let amount: Double
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("₹\(amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                .font(.subheadline).bold()
                .foregroundColor(.primary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

struct DonutChartView: View {
    let principal: Double
    let interest: Double
    let fees: Double
    let total: Double
    
    var body: some View {
        let principalFraction = principal / total
        let interestFraction = interest / total
        
        ZStack {
            // Principal Arc
            Circle()
                .trim(from: 0, to: CGFloat(principalFraction))
                .stroke(DS.primary, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Interest Arc
            Circle()
                .trim(from: CGFloat(principalFraction), to: CGFloat(principalFraction + interestFraction))
                .stroke(DS.primary, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Fees Arc
            Circle()
                .trim(from: CGFloat(principalFraction + interestFraction), to: 1.0)
                .stroke(DS.danger, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Center Text
            VStack {
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("₹\(total.formatted(.number.notation(.compactName).precision(.fractionLength(2))))")
                    .font(.title2).bold()
                    .foregroundColor(.primary)
            }
        }
        .padding(20)
    }
}

struct LoanCostBreakdownView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoanCostBreakdownView()
        }
    }
}
