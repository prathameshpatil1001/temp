import SwiftUI
import Combine

class EMICalculatorViewModel: ObservableObject {
    @Published var loanAmount: Double = 150000
    @Published var interestRate: Double = 10.5
    
    // NEW: What-if controls
    @Published var customEMI: Double = 7000
    @Published var customTenure: Double = 24
    
    func calculateEMI() -> Double {
        let r = (interestRate / 12) / 100
        let n = customTenure
        return (loanAmount * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
    }
}

struct EMICalculatorView: View {
    @StateObject var viewModel = EMICalculatorViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                Text("What-If Simulator")
                    .font(.largeTitle).bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // EMI Slider
                VStack(alignment: .leading) {
                    Text("Monthly EMI")
                    Slider(value: $viewModel.customEMI, in: 1000...50000)
                    Text("₹\(Int(viewModel.customEMI))")
                        .bold()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // NEW TENURE SLIDER
                VStack(alignment: .leading) {
                    Text("Tenure (Months)")
                    Slider(value: $viewModel.customTenure, in: 6...360)
                    Text("\(Int(viewModel.customTenure)) months")
                        .bold()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Result
                VStack(spacing: 10) {
                    Text("Estimated EMI")
                    Text("₹\(Int(viewModel.calculateEMI()))")
                        .font(.largeTitle)
                        .bold()
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
