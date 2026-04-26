//
//  EarningsSummaryCard.swift
//  LoanApp
//
//  Features/Earnings/Views/EarningsSummaryCard.swift
//

import SwiftUI

struct EarningsSummaryCard: View {
    let stats: EarningsStats
    
    var body: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.9),
                            Color.blue.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 200, height: 200)
                .offset(x: 120, y: -80)
            
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 150, height: 150)
                .offset(x: -100, y: 100)
            
            VStack(alignment: .leading, spacing: 16) {
                // Total Lifetime Earnings
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL LIFETIME EARNINGS")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1)
                    
                    Text(stats.formattedLifetimeEarnings)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.vertical, 4)
                
                // This Month and Pending
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THIS MONTH")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.5)
                        
                        Text(stats.formattedMonthEarnings)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PENDING PAYOUT")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(0.5)
                        
                        Text(stats.formattedPendingPayout)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                    }
                }
            }
            .padding(24)
        }
        .frame(height: 200)
        .padding(.horizontal, 16)
    }
}

#Preview {
    EarningsSummaryCard(
        stats: EarningsStats(
            totalLifetimeEarnings: 234600,
            thisMonthEarnings: 26550,
            pendingPayout: 15000,
            paidTransactionsCount: 4,
            pendingTransactionsCount: 2,
            averagePayoutRate: 1.2,
            totalTransactionsCount: 6
        )
    )
    .padding(.vertical)
}
