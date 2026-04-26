//
//  TimelineSection.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//
import SwiftUI

struct TimelineSection: View {
    let steps: [TimelineStep]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Payment Timeline")
                .font(AppFont.headline())
                .foregroundColor(Color.textPrimary)

            ForEach(steps, id: \.title) { step in
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(step.isCompleted ? Color.statusApproved : Color.borderMedium)
                        .frame(width: 10, height: 10)

                    Text(step.title)
                        .font(AppFont.body())
                        .foregroundColor(step.isCompleted ? Color.textPrimary : Color.textSecondary)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .cardShadow()
    }
}
