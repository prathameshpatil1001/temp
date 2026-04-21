import SwiftUI
import Combine

class PrepaymentViewModel: ObservableObject {
    @Published var prepaymentAmount: Double = 50000
    
    let currentBalance: Double = 312000
    let originalInterestRemaining: Double = 35000
    
    var interestSaved: Double {
        // Simplified dummy calculation for demonstration
        (prepaymentAmount * 0.25)
    }
    
    var newTenureMonths: Int {
        // Simplified dummy calculation for demonstration
        let reduction = Int(prepaymentAmount / 20000)
        return max(18 - reduction, 1)
    }
}

struct PrepaymentCalculatorView: View {
    @StateObject var viewModel = PrepaymentViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prepayment Calculator")
                        .font(.largeTitle).bold()
                    Text("See how a lump-sum payment reduces your debt.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Prepayment Input
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Part Payment Amount")
                            .font(.headline)
                        Spacer()
                        Text("₹\(viewModel.prepaymentAmount.formatted(.number.grouping(.automatic)))")
                            .font(.title2).bold()
                            .foregroundColor(.mainBlue)
                    }
                    
                    Slider(value: $viewModel.prepaymentAmount, in: 10000...300000, step: 5000)
                        .accentColor(.mainBlue)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                // Impact Results Card
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Total Interest Saved")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("₹\(viewModel.interestSaved.formatted(.number.grouping(.automatic)))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color(hex: "#00C48C"))
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Original Tenure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("18 Months")
                                .font(.headline)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("New Tenure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.newTenureMonths) Months")
                                .font(.headline)
                                .foregroundColor(.mainBlue)
                        }
                    }
                }
                .padding(24)
                .background(DS.primaryLight.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DS.primary.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
                
                // Info Banner
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.mainBlue)
                    Text("Prepayments are processed against your principal outstanding. Your monthly EMI will remain the same, but your tenure will drop.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(DS.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrepaymentCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        PrepaymentCalculatorView()
    }
}
