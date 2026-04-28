//
//  AdminRiskView.swift
//  lms_project
//
//  TAB 3 — Risk Control Panel
//  Operational two-panel layout with collapsible sidebar and actionable task management.
//

import SwiftUI

struct AdminRiskView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var riskVM: AdminRiskViewModel
    @EnvironmentObject var collectionsVM: AdminCollectionsViewModel
    @EnvironmentObject var messagesVM: MessagesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    @Binding var selectedTab: Int

    @State private var sidebarCollapsed = false
    @State private var showAssignSheet: ActionItem? = nil
    @State private var showMessageSheet: ActionItem? = nil
    
    // Resolution confirmation
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    @State private var confirmationAction: (() -> Void)?
    
    // Toast state
    @State private var showToast = false
    @State private var toastMessage = ""
    
    // Modals
    @State private var activeInvestigation: ActionItem?
    @State private var activeOverride: ActionItem?

    // MARK: - Mock Data Models
    
    struct ActionItem: Identifiable {
        let id: String
        let loanId: String
        let issue: String
        let severity: String // High, Medium, Low
        let time: String
        var officer: String
        var details: String? = nil
        var signals: [String]? = nil
    }
    
    // Backend-backed action lists (derived from applications until backend exposes explicit risk events)
    @State private var slaBreaches: [ActionItem] = []
    @State private var fraudAlerts: [ActionItem] = []
    @State private var policyViolations: [ActionItem] = []
    @State private var stuckApps: [ActionItem] = []
    @State private var officerOverrides: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // LEFT SIDEBAR (Collapsible)
                        if !sidebarCollapsed {
                            riskSidebar
                                .frame(width: 280)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            
                            Divider()
                        }
                        
                        // RIGHT PANEL
                        rightPanelContent
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Risk Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sidebarCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { ProfileNavButton(showProfile: $showProfile) }
            }
            // Assignment Modal
            .sheet(item: $showAssignSheet) { item in
                ReassignOfficerSheet(actionItem: item) { newOfficer in
                    updateOfficer(for: item, to: newOfficer)
                }
            }
            // Messaging Modal
            .sheet(item: $showMessageSheet) { item in
                MessageOfficerSheet(actionItem: item)
            }
            .sheet(item: $activeInvestigation) { item in
                InvestigationModal(item: item, 
                                   adminVM: adminVM,
                                   onMarkFalsePositive: {
                                       confirmationMessage = "Mark this as false positive?"
                                       confirmationAction = { resolveFraud(item: item, message: "Marked as False Positive") }
                                       showConfirmation = true
                                   },
                                   onConfirmFraud: {
                                       confirmationMessage = "Confirm this as fraud?"
                                       confirmationAction = { resolveFraud(item: item, message: "Fraud Confirmed and Resolved") }
                                       showConfirmation = true
                                   })
            }
            .sheet(item: $activeOverride) { item in
                OverrideModal(item: item, onApprove: {
                    withAnimation { policyViolations.removeAll { $0.id == item.id } }
                })
            }
            .confirmationDialog(confirmationMessage, isPresented: $showConfirmation, titleVisibility: .visible) {
                Button("Confirm", role: .destructive) { confirmationAction?() }
                Button("Cancel", role: .cancel) {}
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    ToastView(message: toastMessage)
                        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40)
                }
            }
            .onAppear {
                riskVM.loadData()
                syncFromBackend()
            }
            .onChange(of: riskVM.applications) { _, _ in
                syncFromBackend()
            }
            .onChange(of: riskVM.fraudFlags) { _, _ in
                syncFromBackend()
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var riskSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar Header — matches LO Applications style
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Risk Analytics")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                let totalActions = slaBreaches.count + fraudAlerts.count + policyViolations.count + stuckApps.count
                if totalActions > 0 {
                    Text("\(totalActions)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Colors.critical)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.critical.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(RiskSection.allCases) { section in
                        sidebarItem(for: section)
                    }
                }
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.sm)
            }
            
            Spacer()
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }
    
    private func sidebarItem(for section: RiskSection) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                adminVM.selectedRiskSection = section
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24)
                
                Text(section.rawValue)
                    .font(Theme.Typography.subheadline.weight(.medium))
                
                Spacer()
                
                if section == .actionRequired {
                    let totalActions = slaBreaches.count + fraudAlerts.count + policyViolations.count + stuckApps.count
                    if totalActions > 0 {
                        Text("\(totalActions)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.critical)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if adminVM.selectedRiskSection == section {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.Colors.adaptivePrimary(colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.12))
                }
            }
            .foregroundStyle(adminVM.selectedRiskSection == section ? Theme.Colors.adaptivePrimary(colorScheme) : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Right Panel
    
    private var rightPanelContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                switch adminVM.selectedRiskSection {
                case .overview:
                    riskDashboardSection
                case .actionRequired:
                    actionRequiredSection
                case .collections:
                    collectionsSection
                case .npa:
                    npaSection
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - 1. OVERVIEW
    
    private var riskDashboardSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // FOIR
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "FOIR Distribution", icon: "chart.bar")
                Text("Fixed Obligation to Income Ratio — target ≤ 50%").font(Theme.Typography.caption).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(foirData, id:\.label) { item in
                        RiskBarRow(label:item.label, value:item.value, valueText:"\(Int(item.value*100))%", warningThreshold:0.50, dangerThreshold:0.60, colorScheme:colorScheme)
                        if item.label != foirData.last?.label { Divider().padding(.leading, Theme.Spacing.md) }
                    }
                }.cardStyle(colorScheme: colorScheme)
            }
            // CIBIL
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "CIBIL Score Distribution", icon: "chart.bar.xaxis")
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(liveCibilData, id:\.label) { item in
                        VStack(spacing: Theme.Spacing.sm) {
                            Text("\(item.count)").font(.system(size:28,weight:.bold,design:.rounded)).foregroundStyle(item.color)
                            Text(item.label).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth:.infinity).padding(Theme.Spacing.md).cardStyle(colorScheme:colorScheme)
                    }
                }
            }
            // LTV
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "LTV Distribution", icon: "percent")
                Text("Loan to Value Ratio — target ≤ 80%").font(Theme.Typography.caption).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(ltvData, id:\.label) { item in
                        RiskBarRow(label:item.label, value:item.value, valueText:"\(Int(item.value*100))%", warningThreshold:0.70, dangerThreshold:0.80, colorScheme:colorScheme)
                        if item.label != ltvData.last?.label { Divider().padding(.leading, Theme.Spacing.md) }
                    }
                }.cardStyle(colorScheme: colorScheme)
            }
            
            // Risk Profile
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                SectionHeader(title: "Applicant Risk Profile", icon: "shield.lefthalf.filled")
                HStack(spacing: Theme.Spacing.md) {
                    riskCountPill(label:"High",count:3,color:Theme.Colors.critical)
                    riskCountPill(label:"Medium",count:8,color:Theme.Colors.warning)
                    riskCountPill(label:"Low",count:12,color:Theme.Colors.success)
                }
            }
        }
    }
    
    private func riskCountPill(label:String,count:Int,color:Color) -> some View {
        VStack(spacing:Theme.Spacing.xs) {
            Text("\(count)").font(.system(size:28,weight:.bold,design:.rounded)).foregroundStyle(color)
            Text(label+" Risk").font(Theme.Typography.caption).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity).padding(Theme.Spacing.md).cardStyle(colorScheme:colorScheme)
    }
    
    // MARK: - 2. ACTION REQUIRED
    
    private var actionRequiredSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Showing: \(adminVM.selectedRiskFilter.rawValue) (\(currentFilterCount))")
                .font(Theme.Typography.headline)
                .foregroundStyle(.secondary)
            
            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(ActionRequiredFilter.allCases) { filter in
                        Button {
                            withAnimation { adminVM.selectedRiskFilter = filter }
                        } label: {
                            Text(filter.rawValue)
                                .font(Theme.Typography.caption)
                                .fontWeight(adminVM.selectedRiskFilter == filter ? .semibold : .regular)
                                .foregroundStyle(adminVM.selectedRiskFilter == filter ? .white : Theme.Colors.adaptivePrimary(colorScheme))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(adminVM.selectedRiskFilter == filter ? Theme.Colors.adaptivePrimary(colorScheme) : Theme.Colors.adaptivePrimary(colorScheme).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Table
            VStack(spacing: 0) {
                // Table Header
                HStack(spacing: Theme.Spacing.md) {
                    tableHeaderLabel("ID", width: 90)
                    tableHeaderLabel("ISSUE", width: nil).frame(maxWidth: .infinity, alignment: .leading)
                    tableHeaderLabel("SEV", width: 70)
                    tableHeaderLabel("TIME", width: 75)
                    tableHeaderLabel(adminVM.selectedRiskFilter == .fraudAlert ? "DETECTED BY" : "OFFICER", width: 140)
                    tableHeaderLabel("ACTIONS", width: 180).frame(alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                
                let items = filteredActionItems
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.Colors.success.opacity(0.6))
                        Text("No issues found. System operating smoothly.")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: Theme.Spacing.md) {
                            Text(item.loanId)
                                .font(Theme.Typography.mono)
                                .font(.system(size: 12))
                                .frame(width: 90, alignment: .leading)
                            
                            Text(item.issue)
                                .font(Theme.Typography.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                            
                            severityBadge(text: item.severity)
                                .frame(width: 70, alignment: .leading)
                            
                            Text(item.time)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 75, alignment: .leading)
                            
                            Text(adminVM.selectedRiskFilter == .fraudAlert ? "System" : item.officer)
                                .font(Theme.Typography.subheadline)
                                .frame(width: 140, alignment: .leading)
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                renderActions(for: item)
                            }
                            .frame(width: 180, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        
                        if item.id != items.last?.id { Divider().padding(.horizontal, 12) }
                    }
                }
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
        }
    }
    
    @ViewBuilder
    private func renderActions(for item: ActionItem) -> some View {
        switch adminVM.selectedRiskFilter {
        case .slaBreach:
            actionButton(title: "Message", icon: "message") { showMessageSheet = item }
            actionButton(title: "Assign", icon: "person.2.badge.gearshape") { showAssignSheet = item }
            
        case .fraudAlert:
            actionButton(title: "Investigate", icon: "magnifyingglass.circle") {
                activeInvestigation = item
            }
            
        case .policyViolation:
            actionButton(title: "Override", icon: "exclamationmark.shield") {
                activeOverride = item
            }
            actionButton(title: "Review Policy", icon: "gearshape") {
                selectedTab = 4 // Navigate to System
                adminVM.selectedSystemSection = "Policy Config"
            }
            
        case .stuckApplication:
            actionButton(title: "Remind", icon: "bell") { showMessageSheet = item }
            actionButton(title: "Reassign", icon: "person.2") { showAssignSheet = item }
        }
    }
    
    private func actionButton(title: String, icon: String, color: Color? = nil, action: @escaping () -> Void) -> some View {
        let resolvedColor = color ?? Theme.Colors.adaptivePrimary(colorScheme)
        return Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(title)
            }
            .font(Theme.Typography.caption2.weight(.bold))
            .foregroundStyle(resolvedColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(resolvedColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Modals

    private func resolveFraud(item: ActionItem, message: String) {
        withAnimation {
            fraudAlerts.removeAll { $0.id == item.id }
            activeInvestigation = nil
            toastMessage = message
            showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showToast = false }
        }
    }
    
    private func investigatePanelContent(for item: ActionItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            InfoSection(title: "Fraud Reason", content: item.details ?? "Suspicious activity detected.")
            
            if let signals = item.signals {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Triggered Signals").font(Theme.Typography.subheadline).fontWeight(.semibold)
                    ForEach(signals, id: \.self) { signal in
                        Label(signal, systemImage: "bolt.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.critical)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.Colors.critical.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            
            InfoSection(title: "Relevant Data Summary", content: "Borrower attempted 3 applications in 24 hours with slightly different income values. Bank statement OCR linked to another active application APP-2024-002.")
        }
    }
    
    private func overridePanelContent(for item: ActionItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            InfoSection(title: "Violation Detail", content: item.details ?? "Policy criteria not met.")
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Admin Remark").font(Theme.Typography.subheadline).fontWeight(.semibold)
                TextEditor(text: .constant("Approving exception based on strong secondary income sources verified via physical visit."))
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .frame(height: 100)
            }
        }
    }
    
    private struct InfoSection: View {
        let title: String
        let content: String
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.Typography.subheadline).fontWeight(.semibold)
                Text(content).font(Theme.Typography.body).foregroundStyle(.secondary)
            }
        }
    }

    private var currentFilterCount: Int {
        filteredActionItems.count
    }
    
    private var filteredActionItems: [ActionItem] {
        switch adminVM.selectedRiskFilter {
        case .slaBreach: return slaBreaches
        case .fraudAlert: return fraudAlerts
        case .policyViolation: return policyViolations
        case .stuckApplication: return stuckApps
        }
    }
    
    private func updateOfficer(for item: ActionItem, to newOfficer: String) {
        officerOverrides[item.id] = newOfficer
        syncFromBackend()
    }

    private func syncFromBackend() {
        let apps = riskVM.applications
        let now = Date()
        let relative = RelativeDateTimeFormatter()

        func officer(for id: String, fallback: String) -> String {
            officerOverrides[id] ?? fallback
        }

        slaBreaches = apps
            .filter { $0.slaStatus == .overdue }
            .prefix(50)
            .map { app in
                let id = "SLA-\(app.id)"
                return ActionItem(
                    id: id,
                    loanId: app.id,
                    issue: "SLA Breach",
                    severity: "High",
                    time: relative.localizedString(for: app.createdAt, relativeTo: now),
                    officer: officer(for: id, fallback: "Unassigned")
                )
            }

        fraudAlerts = riskVM.fraudFlags
            .prefix(50)
            .map { flag in
                let id = "FRAUD-\(flag.applicationId)"
                return ActionItem(
                    id: id,
                    loanId: flag.applicationId,
                    issue: "Risk Signal",
                    severity: flag.severity == .high ? "High" : "Medium",
                    time: relative.localizedString(for: flag.flaggedAt, relativeTo: now),
                    officer: officer(for: id, fallback: "System"),
                    details: flag.reason,
                    signals: flag.reason.components(separatedBy: " · ")
                )
            }

        policyViolations = apps
            .filter {
                let foirRatio = $0.financials.foir > 0 ? (Double($0.financials.foir) / 100.0) : $0.financials.dtiRatio
                return foirRatio > 0.50 || $0.financials.ltvRatio > 0.80
            }
            .prefix(50)
            .map { app in
                let id = "POL-\(app.id)"
                let foirRatio = app.financials.foir > 0 ? (Double(app.financials.foir) / 100.0) : app.financials.dtiRatio
                let issue: String
                let detail: String
                if app.financials.ltvRatio > 0.80 {
                    issue = "LTV Exceeded"
                    detail = "LTV is \(Int((app.financials.ltvRatio * 100).rounded()))% (Max allowed: 80%)"
                } else {
                    issue = "FOIR High"
                    detail = "FOIR is \(Int((foirRatio * 100).rounded()))% (Limit: 50%)"
                }
                return ActionItem(
                    id: id,
                    loanId: app.id,
                    issue: issue,
                    severity: "Medium",
                    time: relative.localizedString(for: app.createdAt, relativeTo: now),
                    officer: officer(for: id, fallback: "Unassigned"),
                    details: detail
                )
            }

        let stuckThreshold = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        stuckApps = apps
            .filter { $0.status == .underReview && $0.createdAt < stuckThreshold }
            .prefix(50)
            .map { app in
                let id = "STUCK-\(app.id)"
                return ActionItem(
                    id: id,
                    loanId: app.id,
                    issue: "Stuck in Verification",
                    severity: "Medium",
                    time: relative.localizedString(for: app.createdAt, relativeTo: now),
                    officer: officer(for: id, fallback: "Unassigned")
                )
            }
    }
    
    private func severityBadge(text: String) -> some View {
        let color: Color = {
            switch text {
            case "High": return Color.red
            case "Medium": return Color.yellow
            default: return Color.gray
            }
        }()
        return Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
    
    private func tableHeaderLabel(_ title: String, width: CGFloat?) -> some View {
        Text(title)
            .font(Theme.Typography.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
    }

    // MARK: - 3. FRAUD DETECTION
    
    private var fraudDetectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Fraud Watchlist", icon: "shield.slash")
            
            VStack(spacing: 0) {
                ForEach(flaggedApps) { app in
                    HStack(spacing: Theme.Spacing.md) {
                        Circle().fill(Theme.Colors.critical).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.borrower).font(Theme.Typography.subheadline).fontWeight(.semibold)
                            Text("\(app.id) · \(app.loanType) · \(app.amount)").font(Theme.Typography.caption).foregroundStyle(.secondary)
                            Text("Reason: \(app.flag)").font(Theme.Typography.caption).foregroundStyle(Theme.Colors.critical)
                        }
                        Spacer()
                        Button("Review") { }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if app.id != flaggedApps.last?.id { Divider().padding(.leading, 32) }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - 4. COLLECTIONS
    
    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Overdue Accounts", icon: "tray.full")
            
            VStack(spacing: 0) {
                let allCases = cases30 + cases60 + cases90
                ForEach(allCases) { ccase in
                    HStack(spacing: Theme.Spacing.md) {
                        Circle().fill(ccase.status.color).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ccase.borrower).font(Theme.Typography.subheadline).fontWeight(.semibold)
                            Text("\(ccase.id) · \(ccase.loanType) · \(ccase.outstanding) overdue").font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        GenericBadge(text: ccase.status.displayName, color: ccase.status.color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if ccase.id != allCases.last?.id { Divider().padding(.leading, 32) }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - 5. NPA
    
    private var npaSection: some View {
        VStack(alignment:.leading,spacing:Theme.Spacing.md) {
            SectionHeader(title:"Non-Performing Assets",icon:"exclamationmark.octagon")
            
            VStack(spacing:0) {
                ForEach(npaLoans) { loan in
                    HStack(spacing:Theme.Spacing.md) {
                        Image(systemName:"exclamationmark.triangle.fill").font(.system(size:16)).foregroundStyle(Theme.Colors.critical)
                        VStack(alignment:.leading,spacing:2) {
                            Text(loan.borrower).font(Theme.Typography.headline)
                            Text("\(loan.id) · \(loan.loanType) · \(loan.outstanding) outstanding").font(Theme.Typography.caption).foregroundStyle(.secondary)
                            Text("Aging: 90+ days past due").font(Theme.Typography.caption).foregroundStyle(Theme.Colors.critical)
                        }
                        Spacer()
                        Button("Manage") { }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.Colors.primary)
                    }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,12)
                    
                    if loan.id != npaLoans.last?.id { Divider().padding(.horizontal, 12) }
                }
            }.cardStyle(colorScheme:colorScheme)
        }
    }

    // MARK: - Helpers & Data
    
    private var foirData: [(label: String, value: Double)] {
        let apps = riskVM.applications
        guard !apps.isEmpty else { return [] }
        let grouped = Dictionary(grouping: apps, by: { $0.loan.type.displayName })
        return grouped.map { (key, values) in
            let ratios = values.map { app in
                let raw = app.financials.foir
                if raw > 0 { return Double(raw) / 100.0 }
                return app.financials.dtiRatio
            }
            let avg = ratios.reduce(0, +) / Double(max(ratios.count, 1))
            return (label: key, value: avg)
        }
        .sorted { $0.label < $1.label }
        .prefix(6)
        .map { $0 }
    }
    
    private var liveCibilData: [(label: String, count: Int, color: Color)] {
        let buckets = riskVM.cibilBuckets
        guard !buckets.isEmpty else {
            return [("750+", 0, Theme.Colors.success), ("650–749", 0, Theme.Colors.warning), ("<650", 0, Theme.Colors.critical)]
        }
        return buckets.map { ($0.label, $0.count, $0.color) }
    }
    
    private var ltvData: [(label: String, value: Double)] {
        let apps = riskVM.applications
        guard !apps.isEmpty else { return [] }
        let grouped = Dictionary(grouping: apps, by: { $0.loan.type.displayName })
        return grouped.map { (key, values) in
            let ratios = values.map { $0.financials.ltvRatio }.filter { $0 > 0 }
            let avg = ratios.isEmpty ? 0 : ratios.reduce(0, +) / Double(ratios.count)
            return (label: key, value: avg)
        }
        .sorted { $0.label < $1.label }
        .prefix(6)
        .map { $0 }
    }

    private let flaggedApps: [FlaggedApplication] = [
        FlaggedApplication(id:"APP-031",borrower:"Ramesh Gupta",loanType:"Personal",amount:"₹5.5L",riskScore:88,risk:.high,flag:"CIBIL 542, DTI 61%"),
        FlaggedApplication(id:"APP-047",borrower:"Kavitha Nair",loanType:"Business",amount:"₹18L",riskScore:76,risk:.high,flag:"Multiple active loans"),
        FlaggedApplication(id:"APP-055",borrower:"Ajay Sharma",loanType:"Home",amount:"₹42L",riskScore:61,risk:.medium,flag:"LTV 84% exceeds cap"),
        FlaggedApplication(id:"APP-062",borrower:"Priya Menon",loanType:"Vehicle",amount:"₹8.2L",riskScore:54,risk:.medium,flag:"Income verification gap"),
        FlaggedApplication(id:"APP-071",borrower:"Suresh Pillai",loanType:"Education",amount:"₹3.8L",riskScore:38,risk:.low,flag:"Document mismatch"),
    ]

    private let cases30: [CollectionCase] = [
        CollectionCase(id:"COL-001",borrower:"Vivek Tiwari",loanType:"Personal Loan",outstanding:"₹2.4L",emi:"₹8,500",agent:"Ravi Kumar",status:.contacted),
    ]
    private let cases60: [CollectionCase] = [
        CollectionCase(id:"COL-004",borrower:"Deepa Nambiar",loanType:"Business Loan",outstanding:"₹7.2L",emi:"₹18,000",agent:"Suresh Nair",status:.escalated),
    ]
    private let cases90: [CollectionCase] = [
        CollectionCase(id:"COL-006",borrower:"Girish Mehta",loanType:"Home Loan",outstanding:"₹34.5L",emi:"₹42,000",agent:"Legal Team",status:.legal),
    ]
    private let npaLoans: [CollectionCase] = [
        CollectionCase(id:"NPA-001",borrower:"Farhan Siddiqui",loanType:"Vehicle Loan",outstanding:"₹5.6L",emi:"₹14,000",agent:"Unassigned",status:.unassigned),
    ]
}

// MARK: - Reassign Officer Sheet

private struct ReassignOfficerSheet: View {
    let actionItem: AdminRiskView.ActionItem
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOfficer: String = ""
    
    private let officers = ["Ravi Kumar", "Priya Sharma", "Deepak Mehta", "Sunita Patel", "Neha Kapoor"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Application Details") {
                    LabeledContent("Loan ID", value: actionItem.loanId)
                    LabeledContent("Current Officer", value: actionItem.officer)
                }
                
                Section("Select New Officer") {
                    Picker("Officer", selection: $selectedOfficer) {
                        ForEach(officers, id: \.self) { officer in
                            Text(officer).tag(officer)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Reassign Task")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { selectedOfficer = actionItem.officer }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedOfficer)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Message Officer Sheet

private struct MessageOfficerSheet: View {
    let actionItem: AdminRiskView.ActionItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var messagesVM: MessagesViewModel
    @State private var messageText = "This application has exceeded SLA. Please take action."
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To: \(actionItem.officer)")
                        .font(Theme.Typography.headline)
                    Text("Regarding: \(actionItem.loanId) - \(actionItem.issue)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .onAppear {
                    if actionItem.issue.contains("SLA") {
                        messageText = "This application has exceeded SLA. Please take action."
                    } else if actionItem.issue.contains("Stuck") {
                        messageText = "This application is stuck in process. Please take action."
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                TextEditor(text: $messageText)
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .frame(height: 150)
                
                Button {
                    // Logic to send message through VM
                    dismiss()
                } label: {
                    Text("Send Message")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.Colors.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Message Officer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Subviews

private struct RiskBarRow: View {
    let label:String; let value:Double; let valueText:String; let warningThreshold:Double; let dangerThreshold:Double; let colorScheme:ColorScheme
    private var textColor: Color {
        if value >= dangerThreshold { return Theme.Colors.critical }
        if value >= warningThreshold { return Theme.Colors.warning }
        return Theme.Colors.success
    }
    var body: some View {
        VStack(spacing:6) {
            HStack { Text(label).font(Theme.Typography.subheadline); Spacer(); Text(valueText).font(Theme.Typography.mono).foregroundStyle(textColor) }
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    RoundedRectangle(cornerRadius:4).fill(Theme.Colors.primary.opacity(0.12)).frame(height:6)
                    RoundedRectangle(cornerRadius:4).fill(Theme.Colors.primary).frame(width:geo.size.width*min(value,1.0),height:6)
                    Rectangle().fill(Theme.Colors.neutral.opacity(0.4)).frame(width:1.5,height:10).offset(x:geo.size.width*warningThreshold-0.75,y:-2)
                }
            }.frame(height:6)
        }.padding(.horizontal,Theme.Spacing.md).padding(.vertical,12)
    }
}

private struct FlaggedApplication: Identifiable {
    let id:String; let borrower:String; let loanType:String; let amount:String; let riskScore:Int; let risk:RiskLevel; let flag:String
}

// MARK: - Modals

struct InvestigationModal: View {
    let item: AdminRiskView.ActionItem
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var onMarkFalsePositive: () -> Void
    var onConfirmFraud: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LOAN ID: \(item.loanId)").font(Theme.Typography.mono).foregroundStyle(.secondary)
                        Text(item.issue).font(Theme.Typography.titleLarge).fontWeight(.bold)
                    }
                    .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        detailRow(title: "Fraud Reason", value: "Multiple applications from same IP", icon: "network")
                        detailRow(title: "Triggered Signals", value: "IP Conflict, Phone Match, Device ID Link", icon: "bolt.shield")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Relevant Data Summary")
                                .font(Theme.Typography.subheadline).fontWeight(.bold)
                            Text("Borrower attempted 3 applications in 24 hours with slightly different income values. Bank statement OCR linked to another active application APP-2024-002.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Fraud Investigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button(action: onMarkFalsePositive) {
                        Text("Mark as False Positive")
                            .font(Theme.Typography.caption.weight(.bold))
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.Colors.primary.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirmFraud) {
                        Text("Confirm Fraud")
                            .font(Theme.Typography.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Theme.Colors.critical)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.Colors.primary).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Typography.caption).foregroundStyle(.secondary)
                Text(value).font(Theme.Typography.subheadline).fontWeight(.medium)
            }
        }
    }
}

struct OverrideModal: View {
    let item: AdminRiskView.ActionItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    var onApprove: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LOAN ID: \(item.loanId)").font(Theme.Typography.mono).foregroundStyle(.secondary)
                        Text(item.issue).font(Theme.Typography.titleLarge).fontWeight(.bold)
                    }
                    .padding(.bottom)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Violation Details").font(Theme.Typography.headline)
                        Text(item.details ?? "No additional details provided.")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Policy Override")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onApprove()
                    dismiss()
                } label: {
                    Text("Approve Exception")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.Colors.primary)
                        .cornerRadius(12)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium])
    }
}

struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .clipShape(Capsule())
            .shadow(radius: 4)
    }
}
