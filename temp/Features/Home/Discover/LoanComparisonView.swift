import SwiftUI
import Combine

// MARK: - View Model
class LoanComparisonViewModel: ObservableObject {
    @Published var loanAmount: Double
    @Published var tenureMonths: Double

    let fixedRate: Double
    let floatingRate: Double

    init(loan: LoanProduct) {
        let maxAmt = Double(loan.maxAmount) ?? 500000
        self.loanAmount = min(500000, maxAmt)
        self.tenureMonths = 60

        let base = Double(loan.baseInterestRate) ?? 10.5
        self.fixedRate = base
        self.floatingRate = Swift.max(base - 1.0, 1.0)
    }

    func calculateEMI(rate: Double) -> Double {
        let r = (rate / 12) / 100
        let n = tenureMonths
        guard r > 0 else { return loanAmount / n }
        return (loanAmount * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
    }

    func calculateTotalInterest(rate: Double) -> Double {
        (calculateEMI(rate: rate) * tenureMonths) - loanAmount
    }
}

// MARK: - Main View
struct LoanComparisonView: View {
    let loan: LoanProduct
    @StateObject private var viewModel: LoanComparisonViewModel

    init(loan: LoanProduct) {
        self.loan = loan
        _viewModel = StateObject(wrappedValue: LoanComparisonViewModel(loan: loan))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Header ──────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare Rates")
                        .font(.largeTitle).bold()
                    Text("Adjust amount and tenure to compare fixed vs. floating EMIs for \(loan.name).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // ── Interactive Sliders ─────────────────────────────────
                VStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Loan Amount")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Text("₹\(viewModel.loanAmount.formatted(.number.grouping(.automatic)))")
                                .font(.headline).bold()
                        }
                        Slider(
                            value: $viewModel.loanAmount,
                            in: (Double(loan.minAmount) ?? 50000)...(Double(loan.maxAmount) ?? 500000),
                            step: 10000
                        )
                        .accentColor(.mainBlue)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Tenure")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(viewModel.tenureMonths)) Months")
                                .font(.headline).bold()
                        }
                        Slider(
                            value: $viewModel.tenureMonths,
                            in: 6...120,
                            step: 6
                        )
                        .accentColor(DS.primary)
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)

                // ── Fixed vs Floating Cards ─────────────────────────────
                HStack(spacing: 16) {
                    ComparisonCard(
                        title: "Fixed Rate",
                        rate: viewModel.fixedRate,
                        emi: viewModel.calculateEMI(rate: viewModel.fixedRate),
                        totalInterest: viewModel.calculateTotalInterest(rate: viewModel.fixedRate),
                        color: .mainBlue,
                        description: "EMI stays constant throughout the tenure. Safe from market rate hikes."
                    )

                    ComparisonCard(
                        title: "Floating Rate",
                        rate: viewModel.floatingRate,
                        emi: viewModel.calculateEMI(rate: viewModel.floatingRate),
                        totalInterest: viewModel.calculateTotalInterest(rate: viewModel.floatingRate),
                        color: DS.success,
                        description: "Starts lower. EMI fluctuates based on RBI repo rate changes."
                    )
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

}

// MARK: - Subcomponents

struct ComparisonCard: View {
    let title: String
    let rate: Double
    let emi: Double
    let totalInterest: Double
    let color: Color
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text("Interest Rate")
                    .font(.caption).foregroundColor(.secondary)
                Text(String(format: "%.1f%% p.a.", rate))
                    .font(.title3).bold()
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated EMI")
                    .font(.caption).foregroundColor(.secondary)
                Text("₹\(emi.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.headline).bold()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Interest")
                    .font(.caption).foregroundColor(.secondary)
                Text("₹\(totalInterest.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.headline).bold()
            }

            Divider()

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1.5))
    }
}
