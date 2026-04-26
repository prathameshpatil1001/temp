//
//  CommissionRateCard.swift
//  LoanApp
//
//  Features/Earnings/Views/CommissionRateCard.swift
//

import SwiftUI

struct CommissionRateCard: View {
    let rates: [CommissionRate]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Group rates by loan type
                    ForEach(Earning.LoanType.allCases, id: \.self) { loanType in
                        if let typeRates = getRates(for: loanType), !typeRates.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                // Header
                                HStack(spacing: 8) {
                                    Image(systemName: loanType.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.brandBlue)
                                    
                                    Text(loanType.rawValue)
                                        .font(.system(size: 17, weight: .semibold))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                
                                // Rate Cards
                                VStack(spacing: 8) {
                                    ForEach(typeRates) { rate in
                                        RateRow(rate: rate)
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Info Note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.brandBlue)
                            Text("Important Information")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Text("Commission is calculated based on the sanctioned loan amount. Payout is released after successful loan disbursement, typically within 15-21 days.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandBlue.opacity(0.05))
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Commission Rates")
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
    
    
    private func getRates(for loanType: Earning.LoanType) -> [CommissionRate]? {
        let filtered = rates.filter { $0.loanType == loanType }
            .sorted { $0.minAmount < $1.minAmount }
        return filtered.isEmpty ? nil : filtered
    }
}

struct RateRow: View {
    let rate: CommissionRate
    
    var body: some View {
        HStack(spacing: 12) {
            // Amount Range
            VStack(alignment: .leading, spacing: 4) {
                Text(rate.formattedRange)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(rate.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Rate Badge
            Text("\(String(format: "%.1f%%", rate.rate))%")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.brandBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.brandBlue.opacity(0.1))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    CommissionRateCard(
        rates: [
            CommissionRate(
                id: "CR1",
                loanType: .homeLoan,
                minAmount: 0,
                maxAmount: 5000000,
                rate: 1.2,
                description: "Standard home loan commission"
            ),
            CommissionRate(
                id: "CR2",
                loanType: .homeLoan,
                minAmount: 5000000,
                maxAmount: nil,
                rate: 1.5,
                description: "Premium home loan commission"
            ),
            CommissionRate(
                id: "CR3",
                loanType: .personalLoan,
                minAmount: 0,
                maxAmount: nil,
                rate: 2.0,
                description: "Personal loan commission"
            )
        ]
    )
}
