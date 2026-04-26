//
//  EarningTransactionRow.swift
//  LoanApp
//
//  Features/Earnings/Views/EarningTransactionRow.swift
//

import SwiftUI

struct EarningTransactionRow: View {
    let earning: Earning
    let payoutText: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusBackgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: earning.status.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(statusIconColor)
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                Text(earning.customerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(earning.loanType.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(earning.loanApplicationId)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // Payout info for pending
                if earning.status == .pending && !payoutText.isEmpty {
                    Text(payoutText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Amount and Date
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(earning.commissionAmount))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(earning.status == .pending && earning.commissionAmount == 0 ? .secondary : .primary)
                
                Text(formatDate(earning.transactionDate))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
    }
    
    private var statusBackgroundColor: Color {
        switch earning.status {
        case .paid:
            return Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1)
        case .pending:
            return Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.1)
        case .processing:
            return Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1)
        case .cancelled:
            return Color.red.opacity(0.1)
        }
    }
    
    private var statusIconColor: Color {
        switch earning.status {
        case .paid:
            return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .pending:
            return Color(red: 1.0, green: 0.6, blue: 0.0)
        case .processing:
            return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .cancelled:
            return .red
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount == 0 {
            return "₹0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return "₹" + (formatter.string(from: NSNumber(value: amount)) ?? "0")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 0) {
        EarningTransactionRow(
            earning: Earning(
                id: "E001",
                loanApplicationId: "A002",
                customerName: "Arjun Mehta",
                loanType: .homeLoan,
                loanAmount: 7500000,
                commissionRate: 1.2,
                commissionAmount: 8750,
                status: .paid,
                transactionDate: Date(),
                expectedPayoutDate: Date(),
                actualPayoutDate: Date(),
                disbursementDate: Date()
            ),
            payoutText: ""
        )
        
        Divider()
        
        EarningTransactionRow(
            earning: Earning(
                id: "E003",
                loanApplicationId: "A001",
                customerName: "Rohit Verma",
                loanType: .businessLoan,
                loanAmount: 12500000,
                commissionRate: 1.5,
                commissionAmount: 15000,
                status: .pending,
                transactionDate: Date(),
                expectedPayoutDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
                actualPayoutDate: nil,
                disbursementDate: Date()
            ),
            payoutText: "Payout releases after disbursement: expected May 3"
        )
    }
}
