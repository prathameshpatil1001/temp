//
//  ManagerDashboardView.swift
//  lms_project
//
//  MANAGER COMMAND CENTER — Refined & Unified
//  Sections: Action Required · Portfolio Health · Loan Disbursement · NPA Analysis
//

import SwiftUI

// MARK: — Period Selector

enum DisbursementPeriod: String, CaseIterable {
    case week  = "Week"
    case month = "Month"
    case year  = "Year"
}

struct DisbursementPoint: Identifiable {
    let id    = UUID()
    let label : String
    let count : Int
}

// MARK: — Main View

struct ManagerDashboardView: View {
    @EnvironmentObject var dashboardVM    : DashboardViewModel
    @EnvironmentObject var applicationsVM : ApplicationsViewModel
    @EnvironmentObject var authVM         : AuthViewModel
    @Environment(\.colorScheme)         private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @Binding var selectedTab : Int
    @Binding var showProfile : Bool

    @State private var isAnimating        = false
    @State private var disbursementPeriod : DisbursementPeriod = .week

    private var primary:  Color { Theme.Colors.adaptivePrimary(colorScheme) }
    private var critical: Color { Theme.Colors.adaptiveCritical(colorScheme) }
    private var surface:  Color { Theme.Colors.adaptiveSurface(colorScheme) }
    private var bg:       Color { Theme.Colors.adaptiveBackground(colorScheme) }
    private var border:   Color { Theme.Colors.adaptiveBorder(colorScheme) }

    // 4 cols landscape / iPad, 2 cols portrait iPhone
    private var fourColGrid: [GridItem] {
        let count = hSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        actionRequiredSection
                        portfolioHealthSection
                        disbursementSection
                        npaSection
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
                applicationsVM.loadData()
                withAnimation(.easeOut(duration: 0.5)) { isAnimating = true }
            }
        }
    }

    private var greetingText: String {
        let name   = authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Manager"
        let hour   = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening"
        return "\(prefix), \(name)"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: — SECTION 1 · Action Required
    // ─────────────────────────────────────────────────────────────────────────

    // MARK: — SECTION 1 · Action Required

    private var actionRequiredSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title: "Action Required", icon: "exclamationmark.circle.fill")

                LazyVGrid(columns: fourColGrid, spacing: 10) {
                    // Pending: Blue if 0, Brand Primary if > 0
                    actionCard(
                        title:   "Pending",
                        count:   pendingCount,
                        icon:    "clock.fill",
                        caption: pendingCount == 0 ? "Queue clear" : "Awaiting review",
                        accent:  pendingCount > 0 ? primary : Theme.Colors.adaptivePrimary(colorScheme)
                    ) { navigateToApprovals(filter: .pending) }

                    // Near SLA: Blue if 0, Brand Primary if > 0
                    actionCard(
                        title:   "Near SLA",
                        count:   nearSLACount,
                        icon:    "clock.badge.exclamationmark.fill",
                        caption: nearSLACount == 0 ? "All within SLA" : "Nearing deadline",
                        accent:  nearSLACount > 0 ? primary : Theme.Colors.adaptivePrimary(colorScheme)
                    ) { navigateToApprovals(filter: .nearSLA) }

                    // Risky: Blue if 0, Critical Red if > 0
                    actionCard(
                        title:   "Risky",
                        count:   highRiskCount,
                        icon:    "shield.fill",
                        caption: highRiskCount == 0 ? "No flags" : "Needs scrutiny",
                        accent:  highRiskCount > 0 ? critical : Theme.Colors.adaptivePrimary(colorScheme)
                    ) { navigateToApprovals(filter: .risky) }

                    // Overdue: Blue if 0, Critical Red if > 0
                    actionCard(
                        title:   "Overdue",
                        count:   overdueCount,
                        icon:    "calendar.badge.exclamationmark",
                        caption: overdueCount == 0 ? "None overdue" : "Past due date",
                        accent:  overdueCount > 0 ? critical : Theme.Colors.adaptivePrimary(colorScheme)
                    ) { navigateToApprovals(filter: .overdue) }
                }
            }
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 14)
        }

    @ViewBuilder
    private func actionCard(
        title:   String,
        count:   Int,
        icon:    String,
        caption: String,
        accent:  Color,
        action:  @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(accent.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(border, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: — SECTION 2 · Portfolio Health
    // ─────────────────────────────────────────────────────────────────────────

    private var portfolioHealthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Portfolio Health", icon: "chart.pie.fill")

            LazyVGrid(columns: fourColGrid, spacing: 10) {
                healthCard(
                    label: "Portfolio Size",
                    value: portfolioSizeText,
                    badge: "Approved",
                    color: primary
                )
                healthCard(
                    label: "NPA Rate",
                    value: String(format: "%.1f%%", npaPercent),
                    badge: npaStatusLabel,
                    color: npaPercent <= 3
                        ? Theme.Colors.adaptiveSuccess(colorScheme)
                        : npaPercent <= 6 ? Theme.Colors.adaptiveWarning(colorScheme)
                        : critical
                )
                healthCard(
                    label: "Applications",
                    value: "\(liveApplications.count)",
                    badge: "All time",
                    color: primary
                )
                healthCard(
                    label: "Approval Rate",
                    value: String(format: "%.0f%%", approvalRate),
                    badge: approvalRate >= 60 ? "On Track" : "Low",
                    color: primary
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 18)
    }

    private func healthCard(label: String, value: String, badge: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.3)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(badge)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(border, lineWidth: 1)
        )
    }

    private var npaStatusLabel: String {
        npaPercent <= 3 ? "Healthy" : npaPercent <= 6 ? "Watch" : "Critical"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: — SECTION 3 · Loan Disbursement
    // ─────────────────────────────────────────────────────────────────────────

    private var disbursementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Loan Disbursement", icon: "chart.line.uptrend.xyaxis")

            VStack(alignment: .leading, spacing: 14) {
                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disbursement Trend")
                            .font(Theme.Typography.headline)
                        Text(disbursementSubtitle)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer()
                    // Period picker
                    HStack(spacing: 0) {
                        ForEach(DisbursementPeriod.allCases, id: \.self) { period in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    disbursementPeriod = period
                                }
                            } label: {
                                Text(period.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(disbursementPeriod == period ? .white : primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(disbursementPeriod == period ? primary : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                PremiumLineChart(
                    data: lineChartData(for: disbursementPeriod),
                    labels: lineChartLabels(for: disbursementPeriod),
                    accentColor: primary,
                    showPoints: true,
                    unit: ""
                )
                .frame(height: 180)
                .padding(.leading, 8)
                .id(disbursementPeriod) // force re-render on period change
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
        .offset(y: isAnimating ? 0 : 22)
    }

    // Converts DisbursementPoint counts → [Double] for PremiumLineChart
    private func lineChartData(for period: DisbursementPeriod) -> [Double] {
        disbursementData(for: period).map { Double($0.count) }
    }

    // Extracts labels for PremiumLineChart
    private func lineChartLabels(for period: DisbursementPeriod) -> [String] {
        disbursementData(for: period).map { $0.label }
    }

    private var disbursementSubtitle: String {
        // Calculate Average for the current period's data
        let currentData = disbursementData(for: disbursementPeriod)
        let totalCount = currentData.reduce(0) { $0 + $1.count }
        
        // Calculate total amount for the current period to get a true average
        let cal = Calendar.current
        let now = Date()
        let approved = liveApplications.filter { $0.status == .approved || $0.status == .managerApproved }
        
        let totalAmount: Double
        switch disbursementPeriod {
        case .week:
            let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now)!
            totalAmount = approved.filter { $0.createdAt >= sevenDaysAgo }.reduce(0) { $0 + $1.loan.amount }
        case .month:
            let thirtyDaysAgo = cal.date(byAdding: .day, value: -30, to: now)!
            totalAmount = approved.filter { $0.createdAt >= thirtyDaysAgo }.reduce(0) { $0 + $1.loan.amount }
        case .year:
            let currentYear = cal.component(.year, from: now)
            totalAmount = approved.filter { cal.component(.year, from: $0.createdAt) == currentYear }.reduce(0) { $0 + $1.loan.amount }
        }
        
        let avgLoanSize = totalCount > 0 ? (totalAmount / Double(totalCount)).currencyFormatted : "₹0"
        
        // Return the updated string
        switch disbursementPeriod {
        case .week:  return "Daily — past 7 days • Avg: \(avgLoanSize)"
        case .month: return "Weekly — this month • Avg: \(avgLoanSize)"
        case .year:  return "Monthly — this year • Avg: \(avgLoanSize)"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: — SECTION 4 · NPA Analysis
    // ─────────────────────────────────────────────────────────────────────────

    private var npaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionHeader(title: "NPA Analysis", icon: "exclamationmark.shield.fill")
                        Spacer()
                        NavigationLink(destination: ManagerNPAAnalyticsView()) {
                            Text("Deep Insights")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(primary)
                        }
                    }
            // Overall banner
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Overall NPA Rate")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                    Text(String(format: "%.1f%%", npaPercent))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            npaPercent <= 3 ? Theme.Colors.adaptiveSuccess(colorScheme)
                            : npaPercent <= 6 ? Theme.Colors.adaptiveWarning(colorScheme)
                            : critical
                        )
                }
                Spacer()
                Text(npaStatusLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        npaPercent <= 3 ? Theme.Colors.adaptiveSuccess(colorScheme)
                        : npaPercent <= 6 ? Theme.Colors.adaptiveWarning(colorScheme)
                        : critical
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (npaPercent <= 3 ? Theme.Colors.adaptiveSuccess(colorScheme)
                         : npaPercent <= 6 ? Theme.Colors.adaptiveWarning(colorScheme)
                         : critical).opacity(0.10)
                    )
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(border, lineWidth: 1)
            )

            // Per-type grid — same 4-col/2-col responsive
            LazyVGrid(columns: fourColGrid, spacing: 10) {
                npaTypeCard(type: .personalLoan, npa: "2.1", color: critical)
                npaTypeCard(type: .homeLoan,      npa: "0.4", color: Theme.Colors.adaptiveSuccess(colorScheme))
                npaTypeCard(type: .businessLoan,  npa: "3.2", color: critical)
                npaTypeCard(type: .vehicleLoan,   npa: "1.5", color: Theme.Colors.adaptiveWarning(colorScheme))
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 26)
    }

    private func npaTypeCard(type: LoanType, npa: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(type.displayName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(npa)%")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemFill))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: geo.size.width * min(CGFloat((Double(npa) ?? 0) / 10.0), 1.0),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(border, lineWidth: 1)
        )
    }

    // MARK: — Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
//            Image(systemName: icon)
//                .font(.system(size: 12, weight: .bold))
//                .foregroundStyle(primary)
            Text(title.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.7)
        }
    }

    // MARK: — Navigation Helpers

    private func navigateToApprovals(filter: ApplicationsViewModel.DashboardFilterType) {
        applicationsVM.activeDashboardFilter = filter
        selectedTab = 1 // Switch to Approvals Tab
    }

    // MARK: — Disbursement Chart Data

    private func disbursementData(for period: DisbursementPeriod) -> [DisbursementPoint] {
        let cal      = Calendar.current
        let now      = Date()
        let approved = liveApplications.filter {
            $0.status == .approved || $0.status == .managerApproved
        }
        switch period {
        case .week:
            let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()
            return (0..<7).reversed().map { offset in
                let day = cal.date(byAdding: .day, value: -offset, to: now)!
                let cnt = approved.filter { cal.isDate($0.createdAt, inSameDayAs: day) }.count
                return DisbursementPoint(label: fmt.string(from: day), count: cnt)
            }
        case .month:
            return (0..<4).reversed().map { offset in
                let wkEnd   = cal.date(byAdding: .weekOfYear, value: -offset, to: now)!
                let wkStart = cal.date(byAdding: .day, value: -6, to: wkEnd)!
                let cnt     = approved.filter { $0.createdAt >= wkStart && $0.createdAt <= wkEnd }.count
                return DisbursementPoint(label: "W\(4 - offset)", count: cnt)
            }
        case .year:
            let yr  = cal.component(.year, from: now)
            let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM"; return f }()
            return (1...12).map { month in
                var comps = DateComponents(); comps.year = yr; comps.month = month
                let date  = cal.date(from: comps) ?? now
                let cnt   = approved.filter {
                    cal.component(.month, from: $0.createdAt) == month &&
                    cal.component(.year,  from: $0.createdAt) == yr
                }.count
                return DisbursementPoint(label: fmt.string(from: date), count: cnt)
            }
        }
    }

    // MARK: — Live Metrics

    private var liveApplications: [LoanApplication] { applicationsVM.applications }

    private var pendingCount: Int {
        liveApplications.filter {
            $0.status == .underReview || $0.status == .managerReview || $0.status == .officerApproved
        }.count
    }
    private var nearSLACount: Int  { liveApplications.filter { $0.slaStatus == .urgent }.count }
    private var highRiskCount: Int {
        liveApplications.filter {
            $0.riskLevel == .high && $0.status != .rejected && $0.status != .managerRejected
        }.count
    }
    private var overdueCount: Int {
        liveApplications.filter { $0.slaStatus == .urgent && $0.status == .underReview }.count
    }
    private var npaPercent: Double {
        let relevant = liveApplications.filter {
            $0.status != .pending && $0.status != .underReview &&
            $0.status != .officerReview && $0.status != .managerReview &&
            $0.status != .officerApproved
        }
        guard !relevant.isEmpty else { return 0 }
        let np = relevant.filter {
            $0.riskLevel == .high && ($0.status == .rejected || $0.status == .managerRejected)
        }.count
        return (Double(np) / Double(relevant.count)) * 100
    }
    private var portfolioSizeText: String {
        liveApplications
            .filter { $0.status == .approved || $0.status == .managerApproved }
            .reduce(0.0) { $0 + $1.loan.amount }
            .currencyFormatted
    }
    private var approvalRate: Double {
        let decided = liveApplications.filter {
            $0.status == .approved || $0.status == .managerApproved ||
            $0.status == .rejected || $0.status == .managerRejected
        }
        guard !decided.isEmpty else { return 0 }
        let approved = decided.filter { $0.status == .approved || $0.status == .managerApproved }.count
        return (Double(approved) / Double(decided.count)) * 100
    }
}

// MARK: — KPIDataCard compatibility shim

struct KPIDataCard: View {
    let title   : String
    let value   : String
    let icon    : String
    let color   : Color
    var showCTA : Bool          = false
    var action  : (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(Theme.Typography.titleLarge)
                        .foregroundStyle(.primary)
                    Text(title)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(Theme.Radius.lg)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
