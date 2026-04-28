//
//  ManagerNPAAnalyticsView.swift
//  lms_project
//
//  Created by Apple on 28/04/26.
//

import SwiftUI
import Charts

struct ManagerNPAAnalyticsView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if applicationsVM.npaLoans.isEmpty {
                    emptyNPAState
                } else {
                    // Chart 1: NPA by Loan Type (Bar Chart)
                    analyticsCard(title: "NPA by Loan Type", icon: "banknote") {
                        Chart(applicationsVM.npaByLoanType) { point in
                            BarMark(
                                x: .value("Count", point.npaCount),
                                y: .value("Type", point.category)
                            )
                            .foregroundStyle(Theme.Colors.adaptiveCritical(colorScheme))
                        }
                    }

                    // Chart 2: NPA by Tenure (Column Chart)
                    analyticsCard(title: "NPA by Tenure Bucket", icon: "calendar") {
                        Chart(applicationsVM.npaByTenure) { point in
                            BarMark(
                                x: .value("Tenure", point.category),
                                y: .value("Count", point.npaCount)
                            )
                            .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("NPA Insights")
    }

    private func analyticsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
                .frame(height: 200)
        }
        .padding()
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1))
    }

    private var emptyNPAState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.adaptiveSuccess(colorScheme))
            Text("No NPA cases found")
                .font(.headline)
            Text("Your portfolio is currently healthy with zero loans overdue beyond 90 days.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
