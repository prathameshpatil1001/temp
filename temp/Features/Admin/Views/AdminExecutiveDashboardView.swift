//
//  AdminExecutiveDashboardView.swift
//  lms_project
//
//  Admin Tab 4 — Executive View
//  NEW FILE: Does not modify any existing views.
//

import SwiftUI

// MARK: - Executive Dashboard

struct AdminExecutiveDashboardView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var showNewPolicySheet = false
    @State private var showSyncBanner    = false

    // MARK: - Mock executive data (inline — no backend changes needed)
    private let portfolioValue     = "₹2,450 Cr"
    private let disbursementTotal  = "₹348 Cr"
    private let npaPercent         = "2.4%"
    private let collectionEff      = "94.7%"

    private let slaData: [(product: String, avgDays: Double, target: Double)] = [
        ("Home Loan",       3.2, 5.0),
        ("Personal Loan",   1.8, 3.0),
        ("Business Loan",   4.1, 5.0),
        ("Vehicle Loan",    2.5, 3.0),
        ("Education Loan",  3.8, 4.0),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        greetingHeader
                        kpiGrid
                        slaSection
                        portfolioBreakdownSection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, 100) // room for FAB
                }

                // Floating Quick Actions
                quickActionsOverlay
            }
            .navigationTitle("Executive View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .overlay(alignment: .top) {
                if showSyncBanner {
                    syncBanner
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showSyncBanner)
            .sheet(isPresented: $showNewPolicySheet) {
                NewPolicySheet()
            }
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Executive Overview")
                    .font(Theme.Typography.titleLarge)
                Text("FY 2024-25 · Q4 · As of today")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Live")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.success)
                    .clipShape(Capsule())
                Text("Updated just now")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - KPI 2×2 Grid

    private var kpiGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Portfolio Health", icon: "chart.bar.xaxis")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Theme.Spacing.md),
                          GridItem(.flexible(), spacing: Theme.Spacing.md)],
                spacing: Theme.Spacing.md
            ) {
                ExecKPICard(label: "Portfolio Value",   value: portfolioValue,    icon: "building.columns.fill",        color: Theme.Colors.primary,  trend: "+4.2%")
                ExecKPICard(label: "Disbursed (MTD)",  value: disbursementTotal,  icon: "indianrupeesign.circle.fill",  color: Theme.Colors.success,  trend: "+12.1%")
                ExecKPICard(label: "NPA Ratio",         value: npaPercent,         icon: "exclamationmark.triangle.fill",color: Theme.Colors.critical, trend: "-0.3%")
                ExecKPICard(label: "Collection Eff.",  value: collectionEff,      icon: "checkmark.seal.fill",          color: Theme.Colors.adaptivePrimary(colorScheme),  trend: "+1.4%")
            }
        }
    }

    // MARK: - SLA Tracking

    private var slaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "SLA Tracking", icon: "timer")

            VStack(spacing: 0) {
                ForEach(slaData, id: \.product) { item in
                    SLARow(product: item.product, avgDays: item.avgDays, targetDays: item.target)
                    if item.product != slaData.last?.product {
                        Divider().padding(.leading, Theme.Spacing.md)
                    }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - Portfolio Breakdown

    private var portfolioBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Portfolio Breakdown", icon: "chart.pie")

            VStack(spacing: 0) {
                breakdownRow(label: "Home Loan",      share: 0.42, amount: "₹1,029 Cr", color: Theme.Colors.primary)
                Divider().padding(.leading, Theme.Spacing.md)
                breakdownRow(label: "Personal Loan",  share: 0.28, amount: "₹686 Cr",   color: Theme.Colors.success)
                Divider().padding(.leading, Theme.Spacing.md)
                breakdownRow(label: "Business Loan",  share: 0.18, amount: "₹441 Cr",   color: Theme.Colors.adaptivePrimary(colorScheme))
                Divider().padding(.leading, Theme.Spacing.md)
                breakdownRow(label: "Vehicle Loan",   share: 0.08, amount: "₹196 Cr",   color: Theme.Colors.warning)
                Divider().padding(.leading, Theme.Spacing.md)
                breakdownRow(label: "Education Loan", share: 0.04, amount: "₹98 Cr",    color: Theme.Colors.neutral)
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private func breakdownRow(label: String, share: Double, amount: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(Theme.Typography.subheadline)
                Spacer()
                Text(amount)
                    .font(Theme.Typography.mono)
                    .foregroundStyle(.primary)
                Text("\(Int(share * 100))%")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * share, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }

    // MARK: - Quick Actions FAB

    private var quickActionsOverlay: some View {
        HStack(spacing: Theme.Spacing.md) {
            fabButton(label: "New Policy", icon: "doc.badge.plus") {
                showNewPolicySheet = true
            }
            fabButton(label: "System Sync", icon: "arrow.triangle.2.circlepath") {
                withAnimation { showSyncBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showSyncBanner = false }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xl)
    }

    private func fabButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(Theme.Typography.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, 13)
            .background(Theme.Colors.primary)
            .clipShape(Capsule())
            .shadow(color: Theme.Colors.primary.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sync Banner

    private var syncBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
            Text("System Sync in progress…")
                .font(Theme.Typography.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Colors.primary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Spacing.lg)
    }
}

// MARK: - Exec KPI Card

private struct ExecKPICard: View {
    let label:  String
    let value:  String
    let icon:   String
    let color:  Color
    let trend:  String

    @Environment(\.colorScheme) private var colorScheme

    private var trendIsPositive: Bool {
        !label.contains("NPA") ? trend.hasPrefix("+") : trend.hasPrefix("-")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                Spacer()
                Text(trend)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(trendIsPositive ? Theme.Colors.success : Theme.Colors.critical)
            }
            Spacer()
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 130)
        .cardStyle(colorScheme: colorScheme)
    }
}

// MARK: - SLA Row

private struct SLARow: View {
    let product:    String
    let avgDays:    Double
    let targetDays: Double

    @Environment(\.colorScheme) private var colorScheme

    private var isOnTrack: Bool { avgDays <= targetDays }
    private var progress: Double { min(avgDays / targetDays, 1.0) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: isOnTrack ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isOnTrack ? Theme.Colors.success : Theme.Colors.warning)
                Text(product)
                    .font(Theme.Typography.subheadline)
                Spacer()
                Text(String(format: "%.1f days", avgDays))
                    .font(Theme.Typography.mono)
                    .foregroundStyle(isOnTrack ? Theme.Colors.success : Theme.Colors.warning)
                Text("/ \(Int(targetDays))d SLA")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOnTrack ? Theme.Colors.success : Theme.Colors.warning)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
}

// MARK: - New Policy Sheet (Minimal Dummy)

private struct NewPolicySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var policyName = ""
    @State private var policyType = 0
    private let policyTypes = ["FOIR", "CIBIL Threshold", "LTV Cap", "Workflow Escalation", "KYC Override"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Policy Details") {
                    TextField("Policy Name", text: $policyName)
                    Picker("Policy Type", selection: $policyType) {
                        ForEach(policyTypes.indices, id: \.self) { i in
                            Text(policyTypes[i]).tag(i)
                        }
                    }
                }
                Section("Effective From") {
                    DatePicker("Start Date", selection: .constant(Date()), displayedComponents: .date)
                }
            }
            .navigationTitle("New Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { dismiss() }
                        .disabled(policyName.isEmpty)
                }
            }
        }
    }
}
