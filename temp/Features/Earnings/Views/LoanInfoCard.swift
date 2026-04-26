//
//  LoanInfoCard.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//


import SwiftUI

struct LoanInfoCard: View {
    let earning: EarningDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Loan Details")
                .font(AppFont.headline())
            
            info("Loan Type", earning.loanType)
            info("Loan Amount", "₹\(Int(earning.loanAmount))")
            info("Loan ID", earning.id)
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(AppRadius.lg)
        .cardShadow()
    }
    
    func info(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.textSecondary)
            Spacer()
            Text(value).font(AppFont.bodyMedium())
        }
    }
}
