//
//  AdminDashboardView.swift
//  lms_project
//
//  EXECUTIVE COMMAND CENTER
//  Elite structural reorganization: Grid-based monitoring, side-by-side outcomes, and footer activity.
//

import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @EnvironmentObject var riskVM: AdminRiskViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    @Binding var selectedTab: Int
    
    @State private var lastRefresh = Date()
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                // Executive Layer (solid in dark mode)
                Theme.Colors.adaptivePrimary(colorScheme).opacity(colorScheme == .dark ? 0.04 : 0.0)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        greetingBar
                        
                        // ROW 1: ACTIONS REQUIRED
                        actionRequiredSection
                        
                        // ROW 2: OPERATIONAL HEALTH
                        operationalPerformanceSection
                        
                        // ROW 3: SYSTEM HEALTH
                        systemHealthSection
                        
                        // ROW 4: RULES & RISK
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            policyEngineCard
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            riskComplianceSection
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        
                        // ROW 4: FINAL OUTCOMES (Side by Side)
                        outcomeMetricsSection
                        
                        // ROW 5: LIVE ACTIVITY (Footer)
                        recentActivitySection
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationTitle("Executive Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                dashboardVM.loadData()
                adminVM.loadData()
                applicationsVM.loadData(autoSelectFirst: false)
                riskVM.loadData()
                withAnimation(.easeOut(duration: 0.6)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private var greetingText: String {
        let name   = authVM.currentUser?.name.split(separator: " ").first.map(String.init) ?? "Manager"
        let hour   = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening"
        return "\(prefix), \(name)"
    }
    
    // MARK: - Greeting Bar
    
    private var greetingBar: some View {
        HStack(alignment: .center) {
            Text(greetingText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("LIVE")
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(Color.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(.top, Theme.Spacing.sm)
        .opacity(isAnimating ? 1 : 0)
    }
    
    // MARK: - 1. ACTIONS REQUIRED
    
    // MARK: - 1. ACTIONS REQUIRED

    private var actionRequiredSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "Action Required", icon: "exclamationmark.circle.fill")
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                // SLA Breaches: Blue if 0, Red if > 0
                statusCard(title: "SLA Breaches",
                           count: slaBreachesCount,
                           color: slaBreachesCount > 0 ? .red : Theme.Colors.adaptivePrimary(colorScheme),
                           icon: "timer",
                           subtext: slaBreachesCount == 0 ? "No overdue SLA" : "Requires attention")
                
                // Fraud Alerts: Blue if 0, Orange if > 0
                statusCard(title: "Fraud Alerts",
                           count: riskVM.fraudFlagCount,
                           color: riskVM.fraudFlagCount > 0 ? .orange : Theme.Colors.adaptivePrimary(colorScheme),
                           icon: "shield.righthalf.filled",
                           subtext: riskVM.fraudFlagCount == 0 ? "No derived flags" : "Review signals")
                
                // Policy Violations: Blue if 0, Orange if > 0
                statusCard(title: "Policy Violations",
                           count: policyViolationCount,
                           color: policyViolationCount > 0 ? .orange : Theme.Colors.adaptivePrimary(colorScheme),
                           icon: "doc.on.doc.fill",
                           subtext: policyViolationCount == 0 ? "Within policy thresholds" : "FOIR/LTV threshold breach")
                
                // Stuck Applications: Blue if 0, Yellow if > 0
                statusCard(title: "Stuck Applications",
                           count: stuckApplicationsCount,
                           color: stuckApplicationsCount > 0 ? .yellow : Theme.Colors.adaptivePrimary(colorScheme),
                           icon: "hourglass.badge.plus",
                           subtext: stuckApplicationsCount == 0 ? "No stuck apps" : "Under review > 3 days")
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
    }
    
    // MARK: - 2. SYSTEM HEALTH
    
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "System Health", icon: "cpu.fill")
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                statusCard(title: "Processing Time", value: "4.2h", color: Theme.Colors.adaptivePrimary(colorScheme), icon: "clock.fill", trend: "↓ 8%", trendPositive: true, subtext: "Limit: 12h")
                statusCard(title: "Applications Today", value: "\(applicationsTodayCount)", color: Theme.Colors.adaptivePrimary(colorScheme), icon: "doc.text.fill", subtext: "From backend feed")
                statusCard(title: "Active Users", value: "\(adminVM.activeUsersCount)", color: Theme.Colors.adaptivePrimary(colorScheme), icon: "person.2.fill", subtext: "From admin directory")
                statusCard(title: "SLA Compliance", value: "\(slaCompliancePercent)%", color: Theme.Colors.adaptivePrimary(colorScheme), icon: "checkmark.shield.fill", subtext: "Target: 95%")
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 25)
    }
    
    private func statusCard(title: String,
                            count: Int? = nil,
                            value: String? = nil,
                            color: Color = Theme.Colors.primary,
                            icon: String,
                            trend: String? = nil,
                            trendPositive: Bool? = nil,
                            subtext: String? = nil) -> some View {
        let accent = color
        return Button(action: {
            switch title {
            case "SLA Breaches":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .slaBreach
                selectedTab = 2
            case "Fraud Alerts":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .fraudAlert
                selectedTab = 2
            case "Policy Overrides", "Policy Violations":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .policyViolation
                selectedTab = 2
            case "Stuck Applications":
                adminVM.selectedRiskSection = .actionRequired
                adminVM.selectedRiskFilter = .stuckApplication
                selectedTab = 2
            default: break
            }
        }) {
            VStack(alignment: .leading, spacing: 12) {
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
                    if let trend = trend {
                        HStack(spacing: 4) {
                            Text(trend)
                                .font(Theme.Typography.caption2)
                            Image(systemName: trendPositive == true ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(trendPositive == true ? Color.green : Color.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(value ?? "\(count ?? 0)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let subtext = subtext {
                        Text(subtext)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private struct MiniSparkline: View {
        let color: Color
        
        var body: some View {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 20))
                path.addCurve(to: CGPoint(x: 40, y: 5), control1: CGPoint(x: 10, y: 25), control2: CGPoint(x: 20, y: 0))
                path.addCurve(to: CGPoint(x: 80, y: 15), control1: CGPoint(x: 60, y: 10), control2: CGPoint(x: 70, y: 20))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
    
    // MARK: - 3. PERFORMANCE TRENDS
    
    private var operationalPerformanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                sectionHeader(title: "Operational Health", icon: "chart.line.uptrend.xyaxis")
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("SLA BREACHES")
                        .font(Theme.Typography.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SLA Breach Trend")
                        .font(Theme.Typography.headline)
                    Text("Daily volume of applications exceeding response time threshold")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding([.horizontal, .top], 20)
                
                PremiumLineChart(
                    data: adminVM.slaBreachTrendData,
                    labels: adminVM.slaBreachTrendLabels,
                    accentColor: .red,
                    showPoints: true,
                    unit: "breaches"
                )
                .frame(height: 180)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.Colors.adaptiveSurface(colorScheme))
                    .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 28)
    }
    
    // MARK: - 4. POLICY ENGINE
    
    private var policyEngineCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "Policy Engine", icon: "shield.righthalf.filled")
            
            VStack(spacing: 1) {
                policyRow(label: "FOIR Threshold", value: "50%", icon: "percent")
                policyRow(label: "Min CIBIL Score", value: "650", icon: "chart.bar.fill")
                policyRow(label: "Auto Approval", value: "ON", icon: "cpu.fill", color: .green)
                policyRow(label: "Last Updated", value: "2h ago", icon: "clock.fill", isLast: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
    }
    
    private func policyRow(label: String, value: String, icon: String, color: Color? = nil, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(label)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(value)
                    .font(Theme.Typography.mono)
                    .foregroundStyle(color ?? .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if !isLast {
                Divider().padding(.leading, 48)
            }
        }
    }
    
    // MARK: - 4. RISK SNAPSHOT
    
    private var riskComplianceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "Risk Analysis", icon: "exclamationmark.shield.fill")
            
            RiskIndexCard(fraud: 3, alerts: 2)
                .frame(maxHeight: .infinity)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 30)
    }
    
    private struct RiskIndexCard: View {
        let fraud: Int
        let alerts: Int
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            VStack(spacing: 0) {
                // Table Header
                HStack(spacing: Theme.Spacing.md) {
                    tableHeaderLabel("MONITOR", width: nil).frame(maxWidth: .infinity, alignment: .leading)
                    tableHeaderLabel("SCORE", width: 70)
                    tableHeaderLabel("RISK LEVEL", width: 90)
                    tableHeaderLabel("STATUS", width: 90)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                
                // Table Rows
                VStack(spacing: 0) {
                    RiskAnalysisRow(title: "Fraud flags", value: "\(fraud)", risk: "Critical", status: "Increasing", color: Color(hex: "FA114F"), icon: "shield.fill")
                    Divider().padding(.horizontal, 12)
                    RiskAnalysisRow(title: "Safety Index", value: "92%", risk: "Optimal", status: "Stable", color: Color(hex: "34C759"), icon: "checkmark.shield.fill")
                    Divider().padding(.horizontal, 12)
                    RiskAnalysisRow(title: "System Alerts", value: "\(alerts)", risk: "Moderate", status: "Decreasing", color: Color(hex: "21DFF0"), icon: "bell.fill")
                    Divider().padding(.horizontal, 12)
                    RiskAnalysisRow(title: "Overrides", value: "12", risk: "Low", status: "Stable", color: .orange, icon: "doc.on.doc.fill")
                }
                .padding(.vertical, 8)
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        
        private func tableHeaderLabel(_ title: String, width: CGFloat?) -> some View {
            Text(title)
                .font(Theme.Typography.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: width, alignment: .leading)
        }
    }
    
    private struct RiskAnalysisRow: View {
        let title: String
        let value: String
        let risk: String
        let status: String
        let color: Color
        let icon: String
        
        var body: some View {
            HStack(spacing: Theme.Spacing.md) {
                // Category
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(title)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Value
                Text(value)
                    .font(Theme.Typography.mono)
                    .frame(width: 70, alignment: .leading)
                
                // Risk Badge
                riskBadge(text: risk, color: color)
                    .frame(width: 90, alignment: .leading)
                
                // Status
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10))
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        
        private var statusIcon: String {
            switch status {
            case "Increasing": return "arrow.up.right"
            case "Decreasing": return "arrow.down.right"
            default: return "minus"
            }
        }
        
        private func riskBadge(text: String, color: Color) -> some View {
            Text(text.uppercased())
                .font(Theme.Typography.caption2)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
    }
    
    
    // MARK: - 5. FINAL OUTCOMES (Side-by-Side)
    
    private var outcomeMetricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "Final Outcomes", icon: "checkmark.seal.fill")
            
            HStack(spacing: Theme.Spacing.md) {
                outcomeCard(label: "NPA RATIO", value: "2.4%", status: "Good", color: Theme.Colors.adaptivePrimary(colorScheme))
                outcomeCard(label: "COLLECTION EFFICIENCY", value: "94.7%", status: "On Track", color: Theme.Colors.success)
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 35)
    }
    
    private func outcomeCard(label: String, value: String, status: String, color: Color) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(color)
            }
            Spacer()
            Text(status)
                .font(Theme.Typography.caption2)
                .foregroundStyle(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .cornerRadius(16)
    }
    
    // MARK: - 6. LIVE ACTIVITY (Footer)
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "Recent Activity", icon: "clock.arrow.circlepath")
            
            VStack(spacing: 0) {
                activityItem(title: "APP-2024-006 approved", actor: "Deepak Mehta", time: "12m ago", color: .green)
                activityItem(title: "Policy Update: Min CIBIL Score matched", actor: "System Rule", time: "1h ago", color: Theme.Colors.adaptivePrimary(colorScheme))
                activityItem(title: "APP-2024-009 escalated to Admin", actor: "Sunita Patel", time: "2h ago", color: .orange)
                activityItem(title: "Suspicious Application detected", actor: "Fraud Engine", time: "3h ago", color: .red, isLast: true)
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 40)
    }
    
    private func activityItem(title: String, actor: String, time: String, color: Color, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.4), radius: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        Text(actor)
                            .foregroundStyle(.secondary)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(time)
                            .foregroundStyle(.tertiary)
                    }
                    .font(Theme.Typography.caption)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            if !isLast {
                Divider().padding(.leading, 40)
            }
        }
    }

    // MARK: - Live metrics (Applications)

    private var liveApplications: [LoanApplication] { applicationsVM.applications }

    private var slaBreachesCount: Int {
        liveApplications.filter { $0.slaStatus == .overdue }.count
    }

    private var applicationsTodayCount: Int {
        let cal = Calendar.current
        return liveApplications.filter { cal.isDateInToday($0.createdAt) }.count
    }

    private var stuckApplicationsCount: Int {
        let threshold = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        return liveApplications.filter { $0.status == .underReview && $0.createdAt < threshold }.count
    }

    private var policyViolationCount: Int {
        liveApplications.filter {
            let foirRatio = $0.financials.foir > 0 ? (Double($0.financials.foir) / 100.0) : $0.financials.dtiRatio
            return foirRatio > 0.50 || $0.financials.ltvRatio > 0.80
        }.count
    }

    private var slaCompliancePercent: Int {
        let total = liveApplications.count
        guard total > 0 else { return 0 }
        let onTime = liveApplications.filter { $0.slaStatus != .overdue }.count
        return Int(((Double(onTime) / Double(total)) * 100.0).rounded())
    }
}

// MARK: - Section Header Helper

extension AdminDashboardView {
    func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
//            Image(systemName: icon)
//                .font(.system(size: 14, weight: .bold))
//                .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
            Text(title.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.7)
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
