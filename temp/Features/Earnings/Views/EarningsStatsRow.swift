//
//  EarningsStatsRow.swift
//  LoanApp
//
//  Features/Earnings/Views/EarningsStatsRow.swift
//

import SwiftUI

struct EarningsStatsRow: View {
    let stats: EarningsStats
    let selectedFilter: EarningsViewModel.EarningFilter
    let onFilterTap: (EarningsViewModel.EarningFilter) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Paid Transactions
            StatCell(
                icon: "checkmark.circle.fill",
                iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),
                title: "Paid",
                value: "\(stats.paidTransactionsCount)",
                subtitle: "transactions",
                isSelected: selectedFilter == .paid
            )
            .onTapGesture {
                onFilterTap(.paid)
            }
            
            // Pending Transactions
            StatCell(
                icon: "clock.fill",
                iconColor: Color(red: 1.0, green: 0.6, blue: 0.0),
                title: "Pending",
                value: "\(stats.pendingTransactionsCount)",
                subtitle: "awaiting",
                isSelected: selectedFilter == .pending
            )
            .onTapGesture {
                onFilterTap(.pending)
            }
            
            // Average Payout Rate
            StatCell(
                icon: "chart.line.uptrend.xyaxis",
                iconColor: Color(red: 0.35, green: 0.34, blue: 0.84),
                title: "Rate",
                value: stats.formattedAverageRate,
                subtitle: "avg. payout",
                isSelected: false
            )
        }
        .padding(.horizontal, 16)
    }
}

struct StatCell: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: isSelected ? iconColor.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? iconColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    EarningsStatsRow(
        stats: EarningsStats(
            totalLifetimeEarnings: 234600,
            thisMonthEarnings: 26550,
            pendingPayout: 15000,
            paidTransactionsCount: 4,
            pendingTransactionsCount: 2,
            averagePayoutRate: 1.2,
            totalTransactionsCount: 6
        ),
        selectedFilter: .all,
        onFilterTap: { _ in }
    )
    .padding(.vertical)
}
