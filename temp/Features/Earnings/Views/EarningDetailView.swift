//
//  EarningDetailView.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//


import SwiftUI
import Combine


struct EarningDetailView: View {
    @StateObject var vm: EarningDetailViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                
                // 🔵 TOP CARD (MATCHES HOME SCREEN)
                TopCommissionCard(earning: vm.earning)
                
                // 📊 DONUT CHART + BREAKDOWN
                CommissionAnalyticsCard(breakdown: vm.earning.breakdown)
                
                // 🏦 LOAN DETAILS
                LoanInfoCard(earning: vm.earning)
                
                // 👤 BORROWER
                BorrowerCard(borrower: vm.earning.borrower)
                
                // ⏳ TIMELINE
                TimelineSection(steps: vm.earning.timeline)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, 40)
        }
        .background(Color.surfaceSecondary)
        .navigationTitle("Earning Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

