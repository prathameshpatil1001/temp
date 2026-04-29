//
//  AdminSystemControlView.swift
//  lms_project
//
//  TAB 5 — System Control with 7 sidebar sections
//

import SwiftUI

struct AdminSystemControlView: View {
    private enum UserManagementSegment: String, CaseIterable, Identifiable {
        case employees = "Employees"
        case dsts = "DSTs"

        var id: String { rawValue }
    }

    private enum EmployeeRoleFilter: String, CaseIterable, Identifiable {
        case all = "All Roles"
        case admin = "Admin"
        case manager = "Manager"
        case loanOfficer = "Loan Officer"

        var id: String { rawValue }

        func matches(_ role: UserRole) -> Bool {
            switch self {
            case .all:
                return true // show all roles the backend returned
            case .admin:
                return role == .admin
            case .manager:
                return role == .manager
            case .loanOfficer:
                return role == .loanOfficer
            }
        }
    }

    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var messagesVM: MessagesViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var showCreateUser = false
    @State private var showCreateDst = false
    @State private var editingUser: User? = nil
    @State private var editingDstUser: User? = nil
    @State private var dstUserPendingRemoval: User? = nil
    @State private var configSaved = false
    @State private var sidebarCollapsed = false
    @State private var userManagementSegment: UserManagementSegment = .employees
    @State private var userManagementSearchText = ""
    @State private var selectedEmployeeBranch = "All Banks"
    @State private var selectedEmployeeRoleFilter: EmployeeRoleFilter = .all

    // Branch management state
    @State private var branchSearchText = ""
    @State private var showCreateBranch = false
    @State private var editingBranch: BranchModel? = nil

    // Policy configuration state
    @State private var foirLimit = 50.0
    @State private var cibilThreshold = 600
    @State private var ltvLimit = 80.0
    @State private var baseInterestRate = 8.5
    @State private var maxLoanAmountMil = 50.0

    // Workflow state
    @State private var managerApprovalThreshold = 10.0
    @State private var autoApprovalEnabled = false
    @State private var autoApprovalCIBIL = 800

    // Verification state
    @State private var panOCR = true
    @State private var aadhaarKYC = true
    @State private var faceMatch = true
    @State private var faceMatchThreshold = 85.0
    @State private var videoKYC = false

    // New Editable Policy/Verification State
    @State private var showRuleModal = false
    @State private var selectedRuleIndex: Int? = nil
    @State private var ruleTextInput = ""
    
    // Document Checklist Modal State
    @State private var showDocumentModal = false
    @State private var selectedDocument: DocumentChecklistItem? = nil
    @State private var documentNameInput = ""
    @State private var documentRequiredInput = true

    // Notification state
    @State private var npaEmailAlert = true
    @State private var smsDocRequest = true
    @State private var dailySummary = true
    @State private var slaBreachAlert = true

    enum SystemSection: String, CaseIterable, Identifiable {
        case userManagement = "User Management"
        case branchManagement = "Branch Management"
        case policyConfig = "Policy Configurations"
        case verificationSettings = "Verification"
        case notifications = "Notifications"
        case auditCompliance = "Audit & Compliance"
        case integrations = "Integrations"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .userManagement: return "person.3"
            case .policyConfig: return "shield.righthalf.filled"
            case .verificationSettings: return "checkmark.seal"
            case .notifications: return "bell"
            case .auditCompliance: return "list.bullet.rectangle.portrait"
            case .integrations: return "network"
            case .branchManagement: return "building.2"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if !sidebarCollapsed {
                            sidebar.frame(width: min(geo.size.width * 0.28, 320))
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Divider()
                        }
                        contentPanel.frame(maxWidth: .infinity)
                    }
                }
            }
            .onAppear {
                if adminVM.selectedSystemSection.isEmpty {
                    adminVM.selectedSystemSection = SystemSection.userManagement.rawValue
                }
                hydratePolicyConfigurationValues()
            }
            .navigationTitle("System Control").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { sidebarCollapsed.toggle() }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { ProfileNavButton(showProfile: $showProfile) }
            }
            .onAppear {
                adminVM.loadData()
                Task {
                    await adminVM.loadDstDataForManagerScope()
                }
                hydratePolicyConfigurationValues()
            }
            .sheet(isPresented: $showCreateUser) { CreateUserSheet(adminVM: adminVM) }
            .sheet(isPresented: $showCreateDst) { SystemControlCreateDstSheet(adminVM: adminVM) }
            .sheet(item: $editingUser) { user in EditUserSheet(adminVM: adminVM, user: user) }
            .sheet(item: $editingDstUser) { user in
                SystemControlEditDstSheet(adminVM: adminVM, user: user)
            }
            .sheet(isPresented: $showCreateBranch) { CreateBranchSheet(adminVM: adminVM) }
            .sheet(item: $editingBranch) { branch in
                EditBranchSheet(adminVM: adminVM, branchModel: branch)
            }
            .alert("Remove DST Agent", isPresented: Binding(
                get: { dstUserPendingRemoval != nil },
                set: { if !$0 { dstUserPendingRemoval = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let user = dstUserPendingRemoval {
                        adminVM.removeDstLocally(user)
                    }
                }
            } message: {
                Text("This removes the DST account from the current device list when backend delete is unavailable.")
            }
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Sidebar Header — matches LO Applications style
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Control")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Text("\(SystemSection.allCases.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.10))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(SystemSection.allCases) { section in
                        let isSelected = adminVM.selectedSystemSection == section.rawValue
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { adminVM.selectedSystemSection = section.rawValue }
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 15))
                                    .foregroundStyle(isSelected ? Theme.Colors.adaptivePrimary(colorScheme) : Color.secondary)
                                    .frame(width: 22)
                                Text(section.rawValue)
                                    .font(Theme.Typography.caption)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 14)
                            .background(isSelected ? Theme.Colors.adaptivePrimary(colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.10) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    // MARK: - Content Panel
        private var contentPanel: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    requestBanner
                    Text(adminVM.selectedSystemSection).font(Theme.Typography.titleLarge)
                    if let section = SystemSection(rawValue: adminVM.selectedSystemSection) {
                        switch section {
                        case .userManagement: userManagementContent
                        case .branchManagement: branchManagementContent
                        case .policyConfig: policyConfigContent
                        case .verificationSettings: verificationContent
                        case .notifications: notificationsContent
                        case .auditCompliance: auditContent
                        case .integrations: integrationsContent
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.adaptiveBackground(colorScheme))
        }

        @ViewBuilder
        private var requestBanner: some View {
            if let error = adminVM.requestError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.critical)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.critical.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            } else if let success = adminVM.requestSuccess {
                Label(success, systemImage: "checkmark.circle.fill")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.success)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.success.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
        }

        // MARK: - 1. User Management (Employees Only)
        private var userManagementContent: some View {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("\(managedActiveCount) active · \(managedUsers.count) shown")
                        .font(Theme.Typography.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showCreateUser = true
                    } label: {
                        Label("Add Employee", systemImage: "plus.circle.fill")
                            .font(Theme.Typography.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Theme.Colors.primary)
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    // Segmented picker removed
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search employees by name, email or branch...", text: $userManagementSearchText)
                        .font(Theme.Typography.subheadline)
                    }
                    .padding(10)
                    .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))

                    HStack(spacing: Theme.Spacing.md) {
                        Menu {
                            Button("All Banks") { selectedEmployeeBranch = "All Banks" }
                            ForEach(employeeBranchOptions, id: \.self) { branch in
                                Button(branch) { selectedEmployeeBranch = branch }
                            }
                        } label: {
                            userManagementFilterPill(
                                title: selectedEmployeeBranch,
                                systemImage: "building.2"
                            )
                        }
                        .buttonStyle(.plain)

                        Menu {
                            ForEach(EmployeeRoleFilter.allCases) { role in
                                Button(role.rawValue) { selectedEmployeeRoleFilter = role }
                            }
                        } label: {
                            userManagementFilterPill(
                                title: selectedEmployeeRoleFilter.rawValue,
                                systemImage: "person.2"
                            )
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }

                VStack(spacing: 0) {
                    if managedUsers.isEmpty {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            Text("No employees found in backend.")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                            Text("All data is loaded live from the server.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                        .padding(.horizontal, Theme.Spacing.lg)
                    } else {
                        ForEach(Array(managedUsers.enumerated()), id: \.element.id) { index, user in
                            userManagementRow(for: user)
                            if index != managedUsers.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }

        private var managedUsers: [User] {
            adminVM.users.filter { user in
                let matchesBranch = selectedEmployeeBranch == "All Banks" || user.branch == selectedEmployeeBranch
                let matchesRole = selectedEmployeeRoleFilter.matches(user.role)
                let matchesSearch = userManagementSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    user.name.localizedCaseInsensitiveContains(userManagementSearchText) ||
                    user.email.localizedCaseInsensitiveContains(userManagementSearchText) ||
                    user.branch.localizedCaseInsensitiveContains(userManagementSearchText) ||
                    user.id.localizedCaseInsensitiveContains(userManagementSearchText)
                return matchesBranch && matchesRole && matchesSearch
            }
        }

        private var employeeBranchOptions: [String] {
            Set(
                adminVM.users
                    .map(\.branch)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0 != "Unassigned" }
            )
            .sorted()
        }

        private var managedActiveCount: Int {
            managedUsers.filter { $0.isActive }.count
        }

        private func userManagementFilterPill(title: String, systemImage: String) -> some View {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(Theme.Typography.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(Capsule())
        }

        private func userManagementRow(for user: User) -> some View {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(user.isActive ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.neutral.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(user.initials)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(user.isActive ? Theme.Colors.primary : Theme.Colors.neutral)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                    Text("\(user.role.displayName) · \(user.branch)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text(user.email)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                HStack(spacing: 8) {
                    sysIconButton(icon: "pencil", color: Theme.Colors.primary) {
                        editingUser = user
                    }
                    sysIconButton(
                        icon: user.isActive ? "person.slash" : "person.badge.plus",
                        color: user.isActive ? Theme.Colors.critical : Theme.Colors.success
                    ) {
                        adminVM.toggleUserStatus(user)
                    }
                }
                GenericBadge(
                    text: user.isActive ? "Active" : "Inactive",
                    color: user.isActive ? Theme.Colors.success : Theme.Colors.neutral
                )
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 10)
        }

    // MARK: - 2. Policy Configuration
    private var policyConfigContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                editRow("FOIR Limit") { stepper(value: $foirLimit, range: 20...70, step: 5, suffix: "%") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("Min CIBIL Threshold") { stepper(value: Binding(get:{Double(cibilThreshold)},set:{cibilThreshold=Int($0)}), range: 500...800, step: 10, suffix: "") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("LTV Limit") { stepper(value: $ltvLimit, range: 50...95, step: 5, suffix: "%") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("Base Interest Rate") { stepper(value: $baseInterestRate, range: 5...20, step: 0.5, suffix: "%") }
                Divider().padding(.leading, Theme.Spacing.md)
                editRow("Max Loan Amount") { stepper(value: $maxLoanAmountMil, range: 10...200, step: 10, suffix: "L") }
            }.cardStyle(colorScheme: colorScheme)

            saveButton("Save Policy Configurations") {
                Task {
                    _ = await adminVM.savePolicyConfigurations(
                        maxLoanAmount: maxLoanAmountMil * 1_000_000,
                        minCIBILScore: cibilThreshold,
                        maxDTIRatio: foirLimit / 100.0,
                        requireDocVerification: panOCR || aadhaarKYC || faceMatch || videoKYC,
                        autoAssignEnabled: autoApprovalEnabled
                    )
                }
            }

            // Eligibility rules
            SectionHeader(title: "Loan Eligibility Rules", icon: "checklist")
            VStack(spacing: 0) {
                ForEach(adminVM.eligibilityRules.indices, id: \.self) { index in
                    HStack {
                        Text(adminVM.eligibilityRules[index]).font(Theme.Typography.subheadline)
                        Spacer()
                        HStack(spacing: 8) {
                            sysIconButton(icon: "pencil", color: Theme.Colors.primary) {
                                selectedRuleIndex = index
                                ruleTextInput = adminVM.eligibilityRules[index]
                                showRuleModal = true
                            }
                            sysIconButton(icon: "trash", color: Theme.Colors.critical) {
                                withAnimation { adminVM.deleteEligibilityRule(at: index) }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                    if index != adminVM.eligibilityRules.count - 1 { Divider().padding(.leading, Theme.Spacing.md) }
                }
                
                // Add Rule Button
                Button {
                    selectedRuleIndex = nil
                    ruleTextInput = ""
                    showRuleModal = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add New Rule")
                    }
                    .font(Theme.Typography.caption).fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .background(Theme.Colors.primary.opacity(0.05))
            }
            .cardStyle(colorScheme: colorScheme)
            .sheet(isPresented: $showRuleModal) {
                ruleFormModal
            }
        }
    }

    // MARK: - 3. Workflow Configuration
    private var workflowConfigContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Approval Flow", icon: "arrow.right.arrow.left")
            VStack(spacing: 0) {
                flowStepRow(step: "1", title: "Loan Officer", desc: "Initial review & document collection", icon: "person.text.rectangle")
                Divider().padding(.leading, Theme.Spacing.md)
                flowStepRow(step: "2", title: "Manager", desc: "Credit assessment & approval/rejection", icon: "person.badge.shield.checkmark")
                Divider().padding(.leading, Theme.Spacing.md)
                flowStepRow(step: "3", title: "Admin", desc: "Final override & escalation handling", icon: "gearshape.2")
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Escalation Rules", icon: "exclamationmark.arrow.triangle.2.circlepath")
            VStack(spacing: 0) {
                escRow(trigger: "Loan > ₹50L", to: "Branch Manager", priority: "High")
                Divider().padding(.leading, Theme.Spacing.md)
                escRow(trigger: "CIBIL < 600", to: "Risk Committee", priority: "High")
                Divider().padding(.leading, Theme.Spacing.md)
                escRow(trigger: "SLA Breach > 7 days", to: "Admin", priority: "Medium")
                Divider().padding(.leading, Theme.Spacing.md)
                escRow(trigger: "3 consecutive rejects", to: "Fraud Team", priority: "Critical")
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Auto-Approval", icon: "bolt.circle")
            VStack(spacing: 0) {
                editRow("Enable Auto-Approval") { Toggle("", isOn: $autoApprovalEnabled).labelsHidden().tint(Theme.Colors.primary) }
                if autoApprovalEnabled {
                    Divider().padding(.leading, Theme.Spacing.md)
                    editRow("Min CIBIL for Auto") { stepper(value: Binding(get:{Double(autoApprovalCIBIL)},set:{autoApprovalCIBIL=Int($0)}), range: 750...900, step: 10, suffix: "") }
                    Divider().padding(.leading, Theme.Spacing.md)
                    editRow("Manager Threshold (₹L)") { stepper(value: $managerApprovalThreshold, range: 5...100, step: 5, suffix: "L") }
                }
            }.cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - 4. Verification Settings
    private var verificationContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "KYC Requirements", icon: "person.badge.shield.checkmark.fill")
            VStack(spacing: 0) {
                toggleConfigRow("PAN Card OCR Verification", isOn: $panOCR)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Aadhaar eKYC Integration", isOn: $aadhaarKYC)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Face Liveness Check", isOn: $faceMatch)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Video KYC (High Value)", isOn: $videoKYC)
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Document Checklist", icon: "doc.badge.gearshape")
            VStack(spacing: 0) {
                ForEach(adminVM.documentChecklist) { item in
                    HStack {
                        Text(item.name).font(Theme.Typography.subheadline)
                        Spacer()
                        GenericBadge(text: item.isRequired ? "Required" : "Optional",
                                     color: item.isRequired ? Theme.Colors.primary : .secondary)
                        HStack(spacing: 8) {
                            sysIconButton(icon: "pencil", color: Theme.Colors.primary) {
                                selectedDocument = item
                                documentNameInput = item.name
                                documentRequiredInput = item.isRequired
                                showDocumentModal = true
                            }
                            sysIconButton(icon: "trash", color: Theme.Colors.critical) {
                                withAnimation { adminVM.documentChecklist.removeAll(where: { $0.id == item.id }) }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                    if item.id != adminVM.documentChecklist.last?.id { Divider().padding(.leading, Theme.Spacing.md) }
                }
                
                // Add Document Button
                Button {
                    selectedDocument = nil
                    documentNameInput = ""
                    documentRequiredInput = true
                    showDocumentModal = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add New Document")
                    }
                    .font(Theme.Typography.caption).fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .background(Theme.Colors.primary.opacity(0.05))
            }
            .cardStyle(colorScheme: colorScheme)
            .sheet(isPresented: $showDocumentModal) {
                documentFormModal
            }

            saveButton("Save Verification Settings") {}
        }
    }

    // MARK: - 5. Notifications
    private var notificationsContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Alert Configuration", icon: "bell.badge")
            VStack(spacing: 0) {
                toggleConfigRow("Email alerts for NPA accounts", isOn: $npaEmailAlert)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("SMS for document requests", isOn: $smsDocRequest)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("Daily summary report emails", isOn: $dailySummary)
                Divider().padding(.leading, Theme.Spacing.md)
                toggleConfigRow("SLA breach notifications", isOn: $slaBreachAlert)
            }.cardStyle(colorScheme: colorScheme)

            SectionHeader(title: "Email/SMS Templates", icon: "envelope.badge")
            VStack(spacing: 0) {
                templateRow(name: "Loan Approved", channel: "Email + SMS", status: "Active")
                Divider().padding(.leading, Theme.Spacing.md)
                templateRow(name: "Document Request", channel: "Email", status: "Active")
                Divider().padding(.leading, Theme.Spacing.md)
                templateRow(name: "EMI Reminder", channel: "SMS", status: "Active")
                Divider().padding(.leading, Theme.Spacing.md)
                templateRow(name: "NPA Notice", channel: "Email", status: "Draft")
            }.cardStyle(colorScheme: colorScheme)

            saveButton("Save Notification Settings") {}
        }
    }

    private func templateRow(name: String, channel: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Theme.Typography.subheadline)
                Text(channel).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            GenericBadge(text: status, color: status == "Active" ? Theme.Colors.success : Theme.Colors.warning)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 13)
    }

    // MARK: - 6. Audit & Compliance
    private var auditContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "System Audit Logs", icon: "list.bullet.rectangle.portrait")
                Spacer()
                Button {
                    let url = ReportExportService.generateAuditCSV(logs: adminVM.auditLogs)
                    presentShareSheet(url)
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.primary)
                }.buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                ForEach(adminVM.auditLogs) { log in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Image(systemName: "clock").font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(log.action).font(Theme.Typography.subheadline).fontWeight(.medium)
                                Spacer()
                                Text(log.timestamp.relativeFormatted).font(Theme.Typography.caption).foregroundStyle(.tertiary)
                            }
                            Text(log.detail).font(Theme.Typography.subheadline).foregroundStyle(.secondary)
                            Text("by \(log.user)").font(Theme.Typography.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                    if log.id != adminVM.auditLogs.last?.id { Divider().padding(.leading, 48) }
                }
            }.cardStyle(colorScheme: colorScheme)
        }
    }

    /// Present UIActivityViewController from the topmost active controller.
    /// Using this directly (instead of a SwiftUI sheet) ensures .csv files
    /// are routed to Files / Numbers and not misidentified as calendar/reminder items.
    private func presentShareSheet(_ url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.excludedActivityTypes = [.addToReadingList, .assignToContact, .openInIBooks]
        guard
            let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        var topVC = root
        while let presented = topVC.presentedViewController { topVC = presented }
        topVC.present(vc, animated: true)
    }

    private func accessLogRow(user: String, action: String, time: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(action).font(Theme.Typography.subheadline)
                Text("by \(user)").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(time).font(Theme.Typography.caption).foregroundStyle(.tertiary)
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    // MARK: - 7. Integrations
    private var integrationsContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "API Configuration", icon: "antenna.radiowaves.left.and.right")
            VStack(spacing: Theme.Spacing.sm) {
                apiCard(name: "CIBIL API", endpoint: "api.cibil.com", status: .healthy, latency: "180ms")
                apiCard(name: "UIDAI (Aadhaar)", endpoint: "uidai.gov.in/api", status: .healthy, latency: "95ms")
                apiCard(name: "GSTN API", endpoint: "api.gst.gov.in", status: .healthy, latency: "120ms")
                apiCard(name: "Core Banking", endpoint: "cbs.bank.internal", status: .healthy, latency: "42ms")
                apiCard(name: "Notification Service", endpoint: "notify.bank.internal", status: .degraded, latency: "820ms")
            }

            SectionHeader(title: "Failed API Calls", icon: "exclamationmark.arrow.circlepath")
            VStack(spacing: 0) {
                failedCallRow(api: "Notification Service", error: "Timeout after 5000ms", time: "12 min ago", retryable: true)
                Divider().padding(.leading, Theme.Spacing.md)
                failedCallRow(api: "GSTN API", error: "Rate limit exceeded", time: "2 hr ago", retryable: false)
            }.cardStyle(colorScheme: colorScheme)
        }
    }

    private func apiCard(name: String, endpoint: String, status: SystemHealth, latency: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle().fill(status.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(Theme.Typography.subheadline)
                Text(endpoint).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(status.displayName).font(Theme.Typography.caption2).foregroundStyle(status.color).fontWeight(.semibold)
                Text(latency).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 13).cardStyle(colorScheme: colorScheme)
    }

    private func failedCallRow(api: String, error: String, time: String, retryable: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(api).font(Theme.Typography.subheadline).fontWeight(.medium)
                Text(error).font(Theme.Typography.caption).foregroundStyle(Theme.Colors.critical)
                Text(time).font(Theme.Typography.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            if retryable {
                Button {  } label: {
                    Label("Retry", systemImage: "arrow.clockwise").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.primary)
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }
    
    // MARK: - 8. Branch Management
    private var branchManagementContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("\(adminVM.branches.count) branches total")
                    .font(Theme.Typography.caption).foregroundStyle(.secondary)
                Spacer()
                Button { showCreateBranch = true } label: {
                    Label("Add Branch", systemImage: "plus.circle")
                        .font(Theme.Typography.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Theme.Colors.primary)
                        .clipShape(Capsule())
                }.buttonStyle(.plain)
            }
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search branches...", text: $branchSearchText)
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            
            // List
            VStack(spacing: 0) {
                let filteredBranches = adminVM.branches.filter { branchSearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(branchSearchText) }
                ForEach(filteredBranches) { branch in
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: "building.2").font(.system(size: 14)).foregroundStyle(Theme.Colors.primary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(branch.name).font(Theme.Typography.subheadline).fontWeight(.medium)
                            Text(branch.location.isEmpty ? "Location: Not specified" : "Location: \(branch.location)").font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        sysIconButton(icon: "pencil", color: Theme.Colors.primary) {
                            editingBranch = branch
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
                    if branch.id != filteredBranches.last?.id { Divider().padding(.leading, 56) }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    // MARK: - Shared Helpers

    private func sysIconButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var ruleFormModal: some View {
        NavigationStack {
            Form {
                Section("Rule Description") {
                    TextEditor(text: $ruleTextInput)
                        .frame(minHeight: 100)
                        .font(Theme.Typography.subheadline)
                }
            }
            .navigationTitle(selectedRuleIndex == nil ? "Add Eligibility Rule" : "Edit Eligibility Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRuleModal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let index = selectedRuleIndex {
                            adminVM.eligibilityRules[index] = ruleTextInput
                        } else {
                            adminVM.eligibilityRules.append(ruleTextInput)
                        }
                        showRuleModal = false
                    }
                    .fontWeight(.bold)
                    .disabled(ruleTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    private func editRow<V: View>(_ label: String, content: () -> V) -> some View {
        HStack { Text(label).font(Theme.Typography.subheadline); Spacer(); content() }
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    private func toggleConfigRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack { Text(label).font(Theme.Typography.subheadline); Spacer(); Toggle("", isOn: isOn).labelsHidden().tint(Theme.Colors.primary) }
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
    }

    private func stepper(value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        HStack {
            Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= step } } label: {
                Image(systemName: "minus.circle").foregroundStyle(Theme.Colors.primary)
            }.buttonStyle(.plain)
            Text(step >= 1 ? "\(Int(value.wrappedValue))\(suffix)" : String(format: "%.1f\(suffix)", value.wrappedValue))
                .font(Theme.Typography.mono).foregroundStyle(Theme.Colors.primary).frame(minWidth: 48)
            Button { if value.wrappedValue < range.upperBound { value.wrappedValue += step } } label: {
                Image(systemName: "plus.circle").foregroundStyle(Theme.Colors.primary)
            }.buttonStyle(.plain)
        }
    }

    private func saveButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            withAnimation { configSaved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { configSaved = false }
        } label: {
            HStack {
                Image(systemName: configSaved ? "checkmark.circle" : "square.and.arrow.down")
                Text(configSaved ? "Saved!" : label).fontWeight(.medium)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: Theme.Layout.buttonHeight)
            .background(configSaved ? Theme.Colors.success : Theme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }.buttonStyle(.plain)
    }

    private func hydratePolicyConfigurationValues() {
        cibilThreshold = adminVM.minCIBILScore
        foirLimit = adminVM.maxDTIRatio * 100.0
        maxLoanAmountMil = max(10.0, adminVM.maxLoanAmount / 1_000_000)
        autoApprovalEnabled = adminVM.autoAssignEnabled
    }

    private var documentFormModal: some View {
        NavigationStack {
            Form {
                Section("Document Details") {
                    TextField("Document Name", text: $documentNameInput)
                    Toggle("Required Field", isOn: $documentRequiredInput)
                        .tint(Theme.Colors.primary)
                }
            }
            .navigationTitle(selectedDocument == nil ? "Add Document" : "Edit Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDocumentModal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let doc = selectedDocument {
                            if let idx = adminVM.documentChecklist.firstIndex(where: { $0.id == doc.id }) {
                                adminVM.documentChecklist[idx].name = documentNameInput
                                adminVM.documentChecklist[idx].isRequired = documentRequiredInput
                            }
                        } else {
                            adminVM.documentChecklist.append(DocumentChecklistItem(name: documentNameInput, isRequired: documentRequiredInput))
                        }
                        showDocumentModal = false
                    }
                    .fontWeight(.bold)
                    .disabled(documentNameInput.isEmpty)
                }
            }
        }
        .presentationDetents([.height(250)])
    }

    private func ruleInfoRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle").font(.system(size: 14)).foregroundStyle(Theme.Colors.success)
            Text(text).font(Theme.Typography.subheadline)
            Spacer()
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    private func flowStepRow(step: String, title: String, desc: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(Theme.Colors.primary.opacity(0.12)).frame(width: 32, height: 32)
                Text(step).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Typography.subheadline).fontWeight(.medium)
                Text(desc).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary)
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
    }

    private func escRow(trigger: String, to: String, priority: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trigger).font(Theme.Typography.subheadline)
                Text("→ \(to)").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            let c: Color = priority == "Critical" ? Theme.Colors.critical : priority == "High" ? Theme.Colors.warning : Theme.Colors.primary
            GenericBadge(text: priority, color: c)
        }.padding(.horizontal, Theme.Spacing.md).padding(.vertical, 13)
    }
}

// MARK: - Edit User Sheet (Local to System Control)
struct EditUserSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    let user: User
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var selectedRole: UserRole
    @State private var branchID: String
    @State private var newBranchName = ""
    @State private var newBranchRegion = ""
    @State private var newBranchCity = ""
    @State private var showDeleteConfirmation = false
    
    private var editableRoles: [UserRole] {
        [.loanOfficer, .manager]
    }
    
    init(adminVM: AdminViewModel, user: User) {
        self.adminVM = adminVM
        self.user = user
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        _phone = State(initialValue: user.phone)
        _selectedRole = State(initialValue: user.role)
        _branchID = State(initialValue: user.branchID ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Edit Information") {
                    TextField("Full Name", text: $name)
                        .disabled(true)
                    Picker("Role", selection: $selectedRole) {
                        ForEach(editableRoles) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .disabled(true)
                    Picker("Branch", selection: $branchID) {
                        Text("Unassigned").tag("__UNASSIGNED__")
                        ForEach(adminVM.branches) { b in
                            Text(b.name).tag(b.id)
                        }
                        Text("+ Create New Branch").tag("+ Create New Branch")
                    }
                    if branchID == "+ Create New Branch" {
                        TextField("New Branch Name", text: $newBranchName)
                        TextField("Region", text: $newBranchRegion)
                        TextField("City", text: $newBranchCity)
                    }
                    Text("Name changes are not supported by the current backend employee update API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Account Details") {
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                    HStack {
                        Text("Employee ID").foregroundStyle(.secondary)
                        Spacer()
                        Text(user.id).foregroundStyle(.primary)
                    }
                    if let employeeCode = user.employeeCode, !employeeCode.isEmpty {
                        HStack {
                            Text("Employee Code").foregroundStyle(.secondary)
                            Spacer()
                            Text(employeeCode).foregroundStyle(.primary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete User")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit: \(user.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            var finalBranchID = branchID
                            if branchID == "+ Create New Branch" {
                                finalBranchID = await adminVM.createBranch(
                                    newBranchName,
                                    region: newBranchRegion,
                                    city: newBranchCity
                                ) ?? ""
                            } else if branchID == "__UNASSIGNED__" {
                                finalBranchID = ""
                            }
                            let finalBranchName = finalBranchID.isEmpty
                                ? "Unassigned"
                                : (adminVM.branches.first(where: { $0.id == finalBranchID })?.name ?? user.branch)
                            let success = await adminVM.updateUser(
                                userId: user.id,
                                name: name,
                                email: email,
                                phone: phone,
                                role: selectedRole,
                                branchID: finalBranchID.isEmpty ? nil : finalBranchID,
                                branchName: finalBranchName
                            )
                            await MainActor.run {
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .confirmationDialog("Delete User", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    let success = await adminVM.deleteUser(user)
                    await MainActor.run {
                        if success {
                            dismiss()
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will deactivate the selected employee account in the backend.")
        }
    }
}

struct SystemControlCreateDstSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Details") {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section {
                    SecureField("Assign Password", text: $password)
                } header: {
                    Text("Login Credentials")
                } footer: {
                    Text("DST users sign in with this email and password.")
                }
            }
            .navigationTitle("New DST Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Creating..." : "Create") {
                        isSaving = true
                        Task {
                            let success = await adminVM.createDstAccount(
                                name: name,
                                email: email,
                                phone: phone,
                                password: password
                            )
                            await MainActor.run {
                                isSaving = false
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(name.isEmpty || email.isEmpty || password.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct SystemControlEditDstSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    let user: User
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var isSaving = false

    init(adminVM: AdminViewModel, user: User) {
        self.adminVM = adminVM
        self.user = user
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        _phone = State(initialValue: user.phone)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Update DST Details") {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Account Info") {
                    HStack {
                        Text("Branch")
                        Spacer()
                        Text(user.branch)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Account ID")
                        Spacer()
                        Text(user.id)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("Edit DST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        isSaving = true
                        Task {
                            let success = await adminVM.updateDstAccount(
                                userID: user.id,
                                name: name,
                                email: email,
                                phone: phone
                            )
                            await MainActor.run {
                                isSaving = false
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(name.isEmpty || email.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Branch Management Sheets
struct CreateBranchSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var region = ""
    @State private var city = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Branch Details") {
                    TextField("Branch Name", text: $name)
                    TextField("Region", text: $region)
                    TextField("City", text: $city)
                }
            }
            .navigationTitle("Create Branch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await adminVM.createBranch(name, region: region, city: city) != nil
                            await MainActor.run {
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }
}

struct EditBranchSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    let branchModel: BranchModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var region: String
    @State private var city: String
    @State private var showDeleteConfirmation = false
    
    init(adminVM: AdminViewModel, branchModel: BranchModel) {
        self.adminVM = adminVM
        self.branchModel = branchModel
        _name = State(initialValue: branchModel.name)
        _region = State(initialValue: branchModel.region)
        _city = State(initialValue: branchModel.city)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Branch Details") {
                    TextField("Branch Name", text: $name)
                    TextField("Region", text: $region)
                    TextField("City", text: $city)
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Branch")
                            Spacer()
                        }
                    }
                    Text("Deleting a branch will remove it from active admin lists.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Branch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await adminVM.updateBranch(
                                branchID: branchModel.id,
                                newName: name,
                                region: region,
                                city: city
                            )
                            await MainActor.run {
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .confirmationDialog("Delete Branch", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    let success = await adminVM.deleteBranch(branchID: branchModel.id)
                    await MainActor.run {
                        if success {
                            dismiss()
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will soft-delete the branch in the backend.")
        }
    }
}
