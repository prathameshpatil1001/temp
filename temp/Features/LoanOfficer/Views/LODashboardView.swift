//
//  LODashboardView.swift
//  lms_project
//

import SwiftUI

struct LODashboardView: View {
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    
    @Binding var selectedTab: Int
    @Binding var showProfile: Bool
    
    @State private var isAnimating = false

    private var primary:  Color { Theme.Colors.adaptivePrimary(colorScheme) }
    private var warning:  Color { Theme.Colors.adaptiveWarning(colorScheme) }
    private var critical: Color { Theme.Colors.adaptiveCritical(colorScheme) }
    private var success:  Color { Theme.Colors.adaptiveSuccess(colorScheme) }
    private var surface:  Color { Theme.Colors.adaptiveSurface(colorScheme) }
    private var bg:       Color { Theme.Colors.adaptiveBackground(colorScheme) }
    private var border:   Color { Theme.Colors.adaptiveBorder(colorScheme) }

    // 4 cols landscape / iPad, 2 cols portrait iPhone
    private var responsiveGrid: [GridItem] {
        let count = hSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
//                        greetingBar
                        portfolioOverviewSection
                        performanceTrendSection
                        recentApplicationsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(greetingText)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                applicationsVM.loadData(autoSelectFirst: false)
                withAnimation(.easeOut(duration: 0.5)) { isAnimating = true }
            }
        }
    }

    // MARK: — Greeting Bar (Unified)

//    private var greetingBar: some View {
//        HStack(alignment: .center) {
//            VStack(alignment: .leading, spacing: 3) {
//                Text(greetingText)
//                    .font(Theme.Typography.titleLarge)
//                HStack(spacing: 5) {
//                    Image(systemName: "mappin.and.ellipse")
//                        .font(.system(size: 11, weight: .semibold))
//                        .foregroundStyle(primary)
//                    Text(authVM.currentUser?.branch ?? "Branch")
//                        .font(Theme.Typography.caption)
//                        .foregroundStyle(.secondary)
//                }
//            }
//            Spacer()
//            HStack(spacing: 5) {
//                Circle().fill(Color.blue).frame(width: 6, height: 6)
//                Text(todayFormatted.uppercased())
//                    .font(Theme.Typography.caption2)
//                    .foregroundStyle(primary)
//            }
//            .padding(.horizontal, 10)
//            .padding(.vertical, 6)
//            .background(primary.opacity(0.10))
//            .clipShape(Capsule())
//        }
//        .opacity(isAnimating ? 1 : 0)
//    }

    private var greetingText: String {
        let name = authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Officer"
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening"
        return "\(prefix), \(name)"
    }

    private var todayFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date())
    }

    // MARK: — Portfolio Overview (Updated to match Health Cards)

    // MARK: — Portfolio Overview

    private var portfolioOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Portfolio Overview", icon: "briefcase.fill")

            LazyVGrid(columns: responsiveGrid, spacing: 10) {
                // Active Cases: Blue if 0, Brand Primary if > 0
                healthCard(label: "Active Cases",
                           value: "\(assignedCount)",
                           badge: "Assigned",
                           color: assignedCount > 0 ? primary : Theme.Colors.adaptivePrimary(colorScheme))
                
                // Pending Review: Blue if 0, Warning Orange if > 0
                healthCard(label: "Pending Review",
                           value: "\(pendingReviewCount)",
                           badge: "In Queue",
                           color: pendingReviewCount > 0 ? warning : Theme.Colors.adaptivePrimary(colorScheme))
                
                // High Risk: Blue if 0, Critical Red if > 0
                healthCard(label: "High Risk",
                           value: "\(highRiskCount)",
                           badge: "Critical",
                           color: highRiskCount > 0 ? critical : Theme.Colors.adaptivePrimary(colorScheme))
                
                // Approved: Always Success Green or Blue if 0
                healthCard(label: "Approved",
                           value: "\(approvedCount)",
                           badge: "Life-time",
                           color: approvedCount > 0 ? success : Theme.Colors.adaptivePrimary(colorScheme))
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 14)
    }

    private func healthCard(label: String, value: String, badge: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
            Text(badge)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(border, lineWidth: 1.5)
        )
    }

    // MARK: — Performance Trend

    private var performanceTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Performance Trend", icon: "chart.line.uptrend.xyaxis")

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(approvedCount) Approved")
                            .font(Theme.Typography.headline)
                        Text("Live from your cases")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(approvalRateText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(success.opacity(0.1))
                        .clipShape(Capsule())
                }

                PremiumLineChart(
                    data: weeklySeries,
                    labels: ["D-6", "D-5", "D-4", "D-3", "D-2", "D-1", "Today"],
                    accentColor: primary,
                    showPoints: true,
                    unit: ""
                )
                .frame(height: 180)
            }
            .padding(14)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(border, lineWidth: 1)
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
    }

    // MARK: — Recent Applications

    private var recentApplicationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(title: "Recent Applications", icon: "clock.arrow.circlepath")
                Spacer()
                Button { withAnimation { selectedTab = 1 } } label: {
                    Text("See All")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(primary)
                }
            }

            VStack(spacing: 0) {
                if activeApplications.isEmpty {
                    emptyRecentState
                } else {
                    ForEach(activeApplications.prefix(5)) { app in
                        Button {
                            applicationsVM.selectApplication(app)
                            withAnimation { selectedTab = 1 }
                        } label: {
                            recentAppRow(app)
                        }
                        if app.id != activeApplications.prefix(5).last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(border, lineWidth: 1)
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 24)
    }

    private func recentAppRow(_ app: LoanApplication) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(app.riskLevel.color.opacity(0.1)).frame(width: 44, height: 44)
                Text(String(app.borrower.name.prefix(1))).font(.system(size: 16, weight: .bold)).foregroundStyle(app.riskLevel.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(app.borrower.name).font(.system(size: 15, weight: .semibold))
                Text(app.loan.amount.currencyFormatted).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(status: app.status)
        }
        .padding(12)
    }

    private var emptyRecentState: some View {
        HStack {
            Spacer()
            Text("No recent applications").font(Theme.Typography.caption).foregroundStyle(.tertiary).padding(30)
            Spacer()
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
//            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(primary)
            Text(title.uppercased()).font(.system(size: 16, weight: .bold)).foregroundStyle(.secondary).tracking(0.7)
        }
    }
}

// MARK: — Logic Extension

private extension LODashboardView {
    var liveApplications: [LoanApplication] { applicationsVM.applications }

    var activeApplications: [LoanApplication] {
        liveApplications.filter {
            $0.status == .pending || $0.status == .underReview || $0.status == .officerReview
        }
    }

    var assignedCount: Int { activeApplications.count }

    var pendingReviewCount: Int {
        activeApplications.filter { $0.status == .underReview || $0.status == .officerReview }.count
    }

    var highRiskCount: Int {
        activeApplications.filter { $0.riskLevel == .high }.count
    }

    var approvedCount: Int {
        liveApplications.filter { $0.status == .approved || $0.status == .officerApproved || $0.status == .managerApproved }.count
    }

    var approvalRateText: String {
        guard !liveApplications.isEmpty else { return "0%" }
        let rate = (Double(approvedCount) / Double(liveApplications.count)) * 100
        return "\(Int(rate.rounded()))% Rate"
    }

    var weeklySeries: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) ?? today
            return Double(liveApplications.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count)
        }
    }
}
