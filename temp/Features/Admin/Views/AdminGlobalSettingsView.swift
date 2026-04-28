//
//  AdminGlobalSettingsView.swift
//  lms_project
//
//  Top-right Profile & Global Settings overlay for Admin role.
//  NEW FILE: Does not modify any existing views.
//

import SwiftUI

// MARK: - Admin Global Settings View

struct AdminGlobalSettingsView: View {
    @EnvironmentObject var authVM:  AuthViewModel
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedSection: SettingsSection = .userManagement

    enum SettingsSection: String, CaseIterable, Identifiable {
        case userManagement  = "Users"
        case configurations  = "Config"
        case system          = "System"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .userManagement: return "person.3.fill"
            case .configurations: return "slider.horizontal.3"
            case .system:         return "server.rack"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    profileHeaderBlock

                    Picker("Section", selection: $selectedSection) {
                        ForEach(SettingsSection.allCases) { sec in
                            Text(sec.rawValue).tag(sec)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)

                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            requestBanner
                            switch selectedSection {
                            case .userManagement: userManagementSection
                            case .configurations: configurationsSection
                            case .system:         systemSection
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Admin Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            authVM.logout()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(Theme.Colors.critical)
                    }
                }
            }
        }
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

    // MARK: - Profile Header

    private var profileHeaderBlock: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 60, height: 60)
                Text(authVM.currentUser?.initials ?? "AD")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(authVM.currentUser?.name ?? "Administrator")
                    .font(Theme.Typography.headline)
                Text(authVM.currentUser?.email ?? "admin@bank.com")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.primary)
                    Text("System Administrator")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }
            Spacer()
            GenericBadge(text: "Admin", color: Theme.Colors.primary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    // MARK: - User Management Section

    private var userManagementSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Role Summary
            SectionHeader(title: "Roles & Permissions", icon: "person.badge.shield.checkmark")

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(UserRole.allCases) { role in
                    let count = adminVM.usersByRole[role] ?? 0
                    rolePermissionRow(role: role, count: count)
                }
            }

            // Permission Matrix
            SectionHeader(title: "Permission Matrix", icon: "lock.shield")

            VStack(spacing: 0) {
                permissionRow(role: "Admin",        permissions: ["Full Access", "Config Edit", "User Mgmt", "Audit View"])
                Divider().padding(.leading, Theme.Spacing.md)
                permissionRow(role: "Manager",      permissions: ["Loan Approve", "Team View", "Reports"])
                Divider().padding(.leading, Theme.Spacing.md)
                permissionRow(role: "Loan Officer", permissions: ["Loan Submit", "Doc Upload", "Client Chat"])
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private func rolePermissionRow(role: UserRole, count: Int) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: role.icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 24)
            Text(role.displayName)
                .font(Theme.Typography.subheadline)
            Spacer()
            Text("\(count) user\(count == 1 ? "" : "s")")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            GenericBadge(text: count > 0 ? "Active" : "None", color: count > 0 ? Theme.Colors.success : Theme.Colors.neutral)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
        .cardStyle(colorScheme: colorScheme)
    }

    private func permissionRow(role: String, permissions: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(role)
                .font(Theme.Typography.subheadline)
                .fontWeight(.medium)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(permissions, id: \.self) { perm in
                        Text(perm)
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Colors.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.primary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
    }

    // MARK: - Configurations Section

    private var configurationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Policy Thresholds
            SectionHeader(title: "Risk Policy Thresholds", icon: "slider.horizontal.3")

            VStack(spacing: 0) {
                configDisplayRow(label: "Minimum CIBIL Score",  value: "\(adminVM.minCIBILScore)",          icon: "chart.line.uptrend.xyaxis")
                Divider().padding(.leading, Theme.Spacing.md)
                configDisplayRow(label: "Max DTI (FOIR) Ratio", value: "\(Int(adminVM.maxDTIRatio * 100))%", icon: "arrow.left.arrow.right")
                Divider().padding(.leading, Theme.Spacing.md)
                configDisplayRow(label: "LTV Cap (Home Loan)",  value: "80%",                               icon: "house.fill")
                Divider().padding(.leading, Theme.Spacing.md)
                configDisplayRow(label: "Max Loan Amount",      value: adminVM.maxLoanAmount.compactFormatted, icon: "indianrupeesign.circle")
                Divider().padding(.leading, Theme.Spacing.md)
                configDisplayRow(label: "SLA — Approval",       value: "7 days",                            icon: "timer")
            }
            .cardStyle(colorScheme: colorScheme)

            // Workflow Escalations
            SectionHeader(title: "Workflow Escalations", icon: "arrow.up.forward.circle")

            VStack(spacing: 0) {
                escalationRow(trigger: "Loan > ₹50L",            recipient: "Branch Manager",  priority: "High")
                Divider().padding(.leading, Theme.Spacing.md)
                escalationRow(trigger: "CIBIL < 600",            recipient: "Risk Committee",  priority: "High")
                Divider().padding(.leading, Theme.Spacing.md)
                escalationRow(trigger: "SLA Breach > 7 days",    recipient: "Admin",           priority: "Medium")
                Divider().padding(.leading, Theme.Spacing.md)
                escalationRow(trigger: "3 consecutive rejects",  recipient: "Fraud Team",      priority: "Critical")
            }
            .cardStyle(colorScheme: colorScheme)

            // KYC Config
            SectionHeader(title: "KYC Verification Config", icon: "person.badge.shield.checkmark.fill")

            VStack(spacing: 0) {
                kycConfigRow(label: "PAN Card OCR Match",       enabled: true)
                Divider().padding(.leading, Theme.Spacing.md)
                kycConfigRow(label: "Aadhaar eKYC",             enabled: true)
                Divider().padding(.leading, Theme.Spacing.md)
                kycConfigRow(label: "Face Liveness Check",      enabled: true)
                Divider().padding(.leading, Theme.Spacing.md)
                kycConfigRow(label: "Video KYC (High Value)",   enabled: adminVM.requireDocVerification)
                Divider().padding(.leading, Theme.Spacing.md)
                kycConfigRow(label: "CKYC Registry Lookup",     enabled: true)
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private func configDisplayRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 22)
            Text(label)
                .font(Theme.Typography.subheadline)
            Spacer()
            Text(value)
                .font(Theme.Typography.mono)
                .foregroundStyle(Theme.Colors.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
    }

    private func escalationRow(trigger: String, recipient: String, priority: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(trigger)
                    .font(Theme.Typography.subheadline)
                Text("→ \(recipient)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let priorityColor: Color = priority == "Critical" ? Theme.Colors.critical :
                                       priority == "High"     ? Theme.Colors.warning   : Theme.Colors.primary
            GenericBadge(text: priority, color: priorityColor)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
    }

    private func kycConfigRow(label: String, enabled: Bool) -> some View {
        HStack {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(enabled ? Theme.Colors.success : Theme.Colors.neutral)
            Text(label)
                .font(Theme.Typography.subheadline)
            Spacer()
            Text(enabled ? "Enabled" : "Disabled")
                .font(Theme.Typography.caption)
                .foregroundStyle(enabled ? Theme.Colors.success : Theme.Colors.neutral)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
    }

    // MARK: - System Section

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // API Integration Status
            SectionHeader(title: "Integration API Status", icon: "antenna.radiowaves.left.and.right")

            VStack(spacing: Theme.Spacing.sm) {
                apiStatusCard(name: "Core Banking System",   endpoint: "cbs.bank.internal",       status: .healthy,  latency: "42ms")
                apiStatusCard(name: "Credit Bureau (CIBIL)", endpoint: "api.cibil.com",            status: .healthy,  latency: "180ms")
                apiStatusCard(name: "KYC API",               endpoint: "kyc.digilocker.gov.in",    status: .healthy,  latency: "95ms")
                apiStatusCard(name: "Notification Service",  endpoint: "notify.bank.internal",     status: .degraded, latency: "820ms")
                apiStatusCard(name: "Payment Gateway",       endpoint: "payments.bank.internal",   status: .healthy,  latency: "55ms")
            }

            // Notification Logs
            SectionHeader(title: "Notification Logs", icon: "bell.badge.fill")

            VStack(spacing: 0) {
                notifLogRow(message: "Loan approved: APP-2024-048", channel: "SMS + Email", time: "2 min ago",  success: true)
                Divider().padding(.leading, Theme.Spacing.md)
                notifLogRow(message: "OTP sent to +91-98765-43210", channel: "SMS",        time: "8 min ago",  success: true)
                Divider().padding(.leading, Theme.Spacing.md)
                notifLogRow(message: "Document reminder: APP-2024-052", channel: "Email",  time: "34 min ago", success: true)
                Divider().padding(.leading, Theme.Spacing.md)
                notifLogRow(message: "Disbursal alert: ₹8.4L to HDFC", channel: "Email",  time: "1 hr ago",   success: false)
                Divider().padding(.leading, Theme.Spacing.md)
                notifLogRow(message: "SLA breach warning (APP-2024-039)", channel: "Push", time: "2 hr ago",   success: true)
            }
            .cardStyle(colorScheme: colorScheme)

            // Audit / Compliance Trail
            SectionHeader(title: "Audit & Compliance Trail", icon: "doc.text.magnifyingglass")

            VStack(spacing: 0) {
                ForEach(adminVM.auditLogs) { log in
                    auditTrailRow(log: log)
                    if log.id != adminVM.auditLogs.last?.id {
                        Divider().padding(.leading, Theme.Spacing.md)
                    }
                }
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private func apiStatusCard(name: String, endpoint: String, status: SystemHealth, latency: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Status dot
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.Typography.subheadline)
                Text(endpoint)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(status.displayName)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(status.color)
                    .fontWeight(.semibold)
                Text(latency)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
        .cardStyle(colorScheme: colorScheme)
    }

    private func notifLogRow(message: String, channel: String, time: String, success: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(success ? Theme.Colors.success : Theme.Colors.critical)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(Theme.Typography.subheadline)
                HStack(spacing: Theme.Spacing.sm) {
                    GenericBadge(text: channel, color: Theme.Colors.primary)
                    Text(time)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }

    private func auditTrailRow(log: AuditLog) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.action)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(log.timestamp.relativeFormatted)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(log.detail)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Text("by \(log.user)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
}
