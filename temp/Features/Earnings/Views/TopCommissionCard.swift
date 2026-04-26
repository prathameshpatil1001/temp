//
//  TopCommissionCard.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//
import SwiftUI

struct TopCommissionCard: View {
    let earning: EarningDetail
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandBlue, Color.brandBlue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                
                Text("TOTAL COMMISSION")
                    .font(AppFont.caption())
                    .foregroundColor(.white.opacity(0.8))
                
                Text("₹\(Int(earning.commission))")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                
                HStack {
                    Text("\(earning.commissionRate, specifier: "%.1f")%")
                        .font(AppFont.subhead())
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(AppFont.subheadMed())
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .frame(height: 140)
        .cornerRadius(AppRadius.lg)
        .cardShadow()
    }
    
    var statusText: String {
        switch earning.status {
        case .paid: return "Paid"
        case .pending: return "Pending"
        case .processing: return "Processing"
        }
    }
}
