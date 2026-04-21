import SwiftUI
import Combine

class WhatIfViewModel: ObservableObject {
    
    @Published var extraEmiAmount: Double = 2000
    @Published var tenureMonths: Double = 60   // NEW
    
    let currentEmi: Double = 14200
    let originalTenure: Double = 72
    
    var newTotalEmi: Double {
        currentEmi + extraEmiAmount
    }
    
    var monthsSaved: Int {
        let reduction = Int(originalTenure - tenureMonths)
        return max(reduction, 0)
    }
    
    var totalInterestSaved: Double {
        Double(monthsSaved) * 4500 + extraEmiAmount * 2
    }
}

struct WhatIfSimulatorView: View {
    @StateObject var viewModel = WhatIfViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("What-If Simulator")
                        .font(.largeTitle).bold()
                    Text("Adjust EMI or tenure to see how your loan changes.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // MARK: - EMI Slider
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Add to Monthly EMI")
                            .font(.headline)
                        Spacer()
                        Text("+ ₹\(viewModel.extraEmiAmount.formatted(.number.grouping(.automatic)))")
                            .font(.title2).bold()
                            .foregroundColor(.secondaryBlue)
                    }
                    
                    Slider(value: $viewModel.extraEmiAmount, in: 500...10000, step: 500)
                        .accentColor(.secondaryBlue)
                    
                    HStack {
                        Text("Current: ₹\(viewModel.currentEmi.formatted(.number.grouping(.automatic)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("New: ₹\(viewModel.newTotalEmi.formatted(.number.grouping(.automatic)))")
                            .font(.subheadline).bold()
                            .foregroundColor(.mainBlue)
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8)
                .padding(.horizontal, 20)
                
                // MARK: - NEW TENURE SLIDER
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Adjust Tenure")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(viewModel.tenureMonths)) months")
                            .font(.title2).bold()
                            .foregroundColor(.mainBlue)
                    }
                    
                    Slider(value: $viewModel.tenureMonths, in: 6...120, step: 1)
                        .accentColor(.mainBlue)
                    
                    HStack {
                        Text("Original: \(Int(viewModel.originalTenure)) months")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("New: \(Int(viewModel.tenureMonths)) months")
                            .font(.subheadline).bold()
                            .foregroundColor(.mainBlue)
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8)
                .padding(.horizontal, 20)
                
                // MARK: - Results
                VStack(spacing: 20) {
                    Text("Impact Summary")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 20) {
                        
                        VStack(spacing: 8) {
                            Text("Save")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(viewModel.monthsSaved)")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.mainBlue)
                            
                            Text("Months")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        VStack(spacing: 8) {
                            Text("Save")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("₹\(viewModel.totalInterestSaved.formatted(.number.notation(.compactName)))")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(Color(hex: "#00C48C"))
                            
                            Text("Interest")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WhatIfSimulatorView_Previews: PreviewProvider {
    static var previews: some View {
        WhatIfSimulatorView()
    }
}
