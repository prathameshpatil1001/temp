import SwiftUI

struct LoanComparisonView: View {
    let loan: LoanProduct
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare Loans")
                        .font(.largeTitle).bold()
                    Text("See how the \(loan.title) stacks up against standard market rates.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Comparison Table
                HStack(spacing: 16) {
                    // Column 1: This Loan
                    VStack(spacing: 16) {
                        Text("This Loan")
                            .font(.headline)
                            .foregroundColor(.mainBlue)
                        
                        ComparisonDataPoint(label: "Interest Rate", value: loan.interestRate)
                        ComparisonDataPoint(label: "Max Tenure", value: "\(loan.maxTenure) Mos")
                        ComparisonDataPoint(label: "Processing Fee", value: "1.5%")
                        ComparisonDataPoint(label: "Approval Time", value: "24 Hours")
                    }
                    .padding(16)
                    .background(Color.lightBlue.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.mainBlue.opacity(0.3), lineWidth: 2)
                    )
                    
                    // Column 2: Market Standard
                    VStack(spacing: 16) {
                        Text("Market Avg")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ComparisonDataPoint(label: "Interest Rate", value: "12-14%")
                        ComparisonDataPoint(label: "Max Tenure", value: "48 Mos")
                        ComparisonDataPoint(label: "Processing Fee", value: "2-3%")
                        ComparisonDataPoint(label: "Approval Time", value: "3-5 Days")
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ComparisonDataPoint: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.subheadline).bold()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
