//
//  BorrowerCard.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//
import SwiftUI

struct BorrowerCard: View {
    let borrower: Borrower
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Borrower Details")
                .font(AppFont.headline())
            
            Text(borrower.name).font(AppFont.bodyMedium())
            Text(borrower.phone).foregroundColor(.textSecondary)
            Text(borrower.city).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(AppRadius.lg)
        .cardShadow()
    }
}
