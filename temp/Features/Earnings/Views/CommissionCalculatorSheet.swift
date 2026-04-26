//
//  CommissionCalculatorSheet.swift
//  LoanApp
//
//  Features/Earnings/Views/CommissionCalculatorSheet.swift
//

import SwiftUI

struct CommissionCalculatorSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: EarningsViewModel
    
    @State private var selectedLoanType: Earning.LoanType = .homeLoan
    @State private var loanAmount: String = ""
    @State private var calculatedCommission: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Input Section
                VStack(spacing: 20) {
                    // Loan Type Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Type")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Menu {
                            ForEach(Earning.LoanType.allCases, id: \.self) { type in
                                Button {
                                    selectedLoanType = type
                                    calculateCommission()
                                } label: {
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedLoanType.icon)
                                    .foregroundColor(.brandBlue)
                                Text(selectedLoanType.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        }
                    }
                    
                    // Loan Amount Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Amount")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("₹")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            TextField("Enter amount", text: $loanAmount)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .medium))
                                .onChange(of: loanAmount) { _ in
                                    calculateCommission()
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding(20)
                
                // Result Section
                if calculatedCommission > 0 {
                    VStack(spacing: 16) {
                        Divider()
                        
                        VStack(spacing: 12) {
                            Text("Estimated Commission")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(viewModel.formatCurrency(calculatedCommission))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.brandBlue)
                            
                            // Commission Rate Info
                            if let rate = getCommissionRate() {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Commission rate: \(String(format: "%.1f%%", rate))%")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Divider()
                        
                        // Commission Breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Breakdown")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Loan Amount")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let amount = Double(loanAmount) {
                                    Text(viewModel.formatCurrency(amount))
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            
                            HStack {
                                Text("Commission Rate")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let rate = getCommissionRate() {
                                    Text("\(String(format: "%.1f%%", rate))%")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Your Commission")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Text(viewModel.formatCurrency(calculatedCommission))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.brandBlue)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // View Rates Button
                Button {
                    viewModel.showCommissionRates = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text("View All Commission Rates")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.brandBlue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.brandBlue, lineWidth: 1.5)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Commission Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private func calculateCommission() {
        guard let amount = Double(loanAmount), amount > 0 else {
            calculatedCommission = 0
            return
        }
        calculatedCommission = viewModel.calculateCommission(for: selectedLoanType, amount: amount)
    }
    
    private func getCommissionRate() -> Double? {
        guard let amount = Double(loanAmount), amount > 0 else { return nil }
        return (calculatedCommission / amount) * 100
    }
}

#Preview {
    CommissionCalculatorSheet(viewModel: EarningsViewModel())
}
