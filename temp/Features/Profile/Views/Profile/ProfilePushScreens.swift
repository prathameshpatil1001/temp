// MARK: - ProfilePushScreens.swift
// All screens pushed from the Profile tab settings rows

import SwiftUI

// MARK: - 1. Notification Settings

struct NotificationSettingsView: View {
    @ObservedObject var vm: ProfileViewModel

    var body: some View {
        List {
            Section("ALERTS") {
                ToggleRow(
                    title: "Push Notifications",
                    subtitle: "Receive alerts on this device",
                    icon: "bell.fill",
                    iconColor: .blue,
                    isOn: $vm.notificationSettings.pushEnabled
                )
                ToggleRow(
                    title: "SMS Alerts",
                    subtitle: "Important updates via SMS",
                    icon: "message.fill",
                    iconColor: .green,
                    isOn: $vm.notificationSettings.smsEnabled
                )
            }

            Section("WHAT TO NOTIFY") {
                ToggleRow(
                    title: "Lead Status Updates",
                    subtitle: "When a lead moves to a new stage",
                    icon: "person.crop.circle.badge.checkmark",
                    iconColor: .indigo,
                    isOn: $vm.notificationSettings.leadStatusUpdates
                )
                ToggleRow(
                    title: "Document Requests",
                    subtitle: "When a loan officer requests a document",
                    icon: "doc.badge.ellipsis",
                    iconColor: .orange,
                    isOn: $vm.notificationSettings.documentRequests
                )
                ToggleRow(
                    title: "Payout Alerts",
                    subtitle: "When commission is processed or pending",
                    icon: "indianrupeesign.circle.fill",
                    iconColor: Color(red: 0.12, green: 0.35, blue: 0.75),
                    isOn: $vm.notificationSettings.payoutAlerts
                )
                ToggleRow(
                    title: "Marketing Messages",
                    subtitle: "Product updates and promotions",
                    icon: "megaphone.fill",
                    iconColor: .secondary,
                    isOn: $vm.notificationSettings.marketingMessages
                )
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { vm.saveNotificationSettings() }
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - 2. Security & PIN

struct SecurityPinView: View {
    @State private var biometricEnabled = true
    @State private var appLockEnabled = true
    @State private var autoLockTimeout = 2  // minutes
    @State private var showChangePIN = false

    let timeouts = [1, 2, 5, 10, 30]

    var body: some View {
        List {
            Section("BIOMETRIC") {
                ToggleRow(
                    title: "Face ID / Touch ID",
                    subtitle: "Use biometrics to unlock the app",
                    icon: "faceid",
                    iconColor: .green,
                    isOn: $biometricEnabled
                )
            }

            Section("APP LOCK") {
                ToggleRow(
                    title: "App Lock",
                    subtitle: "Require authentication on open",
                    icon: "lock.fill",
                    iconColor: .blue,
                    isOn: $appLockEnabled
                )
                if appLockEnabled {
                    Picker("Auto-lock after", selection: $autoLockTimeout) {
                        ForEach(timeouts, id: \.self) { t in
                            Text("\(t) min").tag(t)
                        }
                    }
                }
            }

            Section("PIN") {
                Button {
                    showChangePIN = true
                } label: {
                    HStack {
                        Label("Change PIN", systemImage: "key.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(Color(.tertiaryLabel))
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                InfoRow(icon: "exclamationmark.shield", text: "Your PIN is stored securely on-device. Bank staff will never ask for your PIN.")
            }
        }
        .navigationTitle("Security & PIN")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChangePIN) {
            ChangePINView()
        }
    }
}

struct ChangePINView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newPIN = ""
    @State private var confirmPIN = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("NEW PIN") {
                    SecureField("Enter 6-digit PIN", text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)
                }
                Section {
                    InfoRow(icon: "info.circle", text: "Use a PIN that's hard to guess. Do not use your date of birth or phone number.")
                }
            }
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { dismiss() }
                        .fontWeight(.semibold)
                        .disabled(newPIN.count < 6 || newPIN != confirmPIN)
                }
            }
        }
    }
}

// MARK: - 3. Privacy

struct PrivacyView: View {
    @State private var analyticsEnabled = true
    @State private var crashReportsEnabled = true

    var body: some View {
        List {
            Section("DATA SHARING") {
                ToggleRow(
                    title: "Usage Analytics",
                    subtitle: "Help improve the app by sharing anonymous usage data",
                    icon: "chart.bar.fill",
                    iconColor: .blue,
                    isOn: $analyticsEnabled
                )
                ToggleRow(
                    title: "Crash Reports",
                    subtitle: "Automatically send crash logs to the team",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    isOn: $crashReportsEnabled
                )
            }

            Section("YOUR RIGHTS (DPDP Act 2023)") {
                NavigationLink {
                    DataRequestView()
                } label: {
                    Label("Request My Data", systemImage: "arrow.down.circle")
                }
                NavigationLink {
                    DataDeletionView()
                } label: {
                    Label("Delete My Account", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }

            Section {
                InfoRow(icon: "shield.fill", text: "All borrower data is encrypted at rest and in transit. Governed by the Digital Personal Data Protection Act, 2023.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataRequestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 48)).foregroundStyle(.blue)
            Text("Request Your Data")
                .font(.title2).fontWeight(.bold)
            Text("We'll compile all data associated with your account and send it to your registered email within 72 hours.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Request Data Export") {}
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("My Data")
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxHeight: .infinity)
    }
}

struct DataDeletionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48)).foregroundStyle(.red)
            Text("Delete Account")
                .font(.title2).fontWeight(.bold)
            Text("This will permanently delete your account, leads, and earnings history. This action cannot be undone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Request Account Deletion") {}
                .foregroundStyle(.red)
                .buttonStyle(.bordered)
                .tint(.red)
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - 4. Help Center

struct HelpCenterView: View {
    let faqs: [(q: String, a: String)] = [
        ("How do I add a new lead?", "Tap the '+ Add Lead' button on the Leads tab, fill in the borrower's basic details and select the loan type and amount."),
        ("When will my commission be paid?", "Commission is processed after loan disbursement, typically within 3 working days. You'll receive a push notification when payment is initiated."),
        ("Why was my lead rejected?", "Rejection reasons are visible in the lead detail screen. Common reasons include CIBIL score below threshold, high FOIR, or incomplete documents."),
        ("How is the Trust Score calculated?", "Trust Score (0–100) is based on your approval rate, document accuracy, SLA adherence, and lead quality over the past 6 months."),
        ("Can I re-submit a rejected application?", "Contact your assigned loan officer via Messages to discuss re-submission options such as adding a co-applicant or adjusting the loan amount."),
    ]

    @State private var expandedIndex: Int? = nil

    var body: some View {
        List {
            Section("FREQUENTLY ASKED QUESTIONS") {
                ForEach(faqs.indices, id: \.self) { i in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedIndex == i },
                            set: { expandedIndex = $0 ? i : nil }
                        )
                    ) {
                        Text(faqs[i].a)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } label: {
                        Text(faqs[i].q)
                            .font(.subheadline).fontWeight(.medium)
                    }
                }
            }

            Section {
                NavigationLink("Video Tutorials") {
                    PlaceholderView(title: "Video Tutorials", icon: "play.rectangle.fill")
                }
                NavigationLink("Product Guides") {
                    PlaceholderView(title: "Product Guides", icon: "book.fill")
                }
            }
        }
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 5. Contact Support

struct ContactSupportView: View {
    var body: some View {
        List {
            Section("REACH US") {
                Button {
                    // Open chat
                } label: {
                    HStack(spacing: 14) {
                        RoundedIconView(icon: "message.fill", color: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chat with Support").font(.body).foregroundStyle(.primary)
                            Text("Average response: 10 minutes").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                Button {
                    if let url = URL(string: "tel://18001234567") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 14) {
                        RoundedIconView(icon: "phone.fill", color: .green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Call 1800-123-4567").font(.body).foregroundStyle(.primary)
                            Text("Mon–Sat, 9 AM – 6 PM").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                Button {
                    if let url = URL(string: "mailto:dstsupport@bank.com") { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 14) {
                        RoundedIconView(icon: "envelope.fill", color: .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Email Support").font(.body).foregroundStyle(.primary)
                            Text("dstsupport@bank.com").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color(.tertiaryLabel))
                    }
                }
            }

            Section("YOUR TICKET HISTORY") {
                Text("No open tickets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 6. Terms & Compliance

struct TermsView: View {
    let docs = [
        ("Terms & Conditions", "Last updated: 1 Jan 2026", "doc.text.fill"),
        ("Privacy Policy", "Last updated: 1 Jan 2026", "shield.fill"),
        ("NBFC Regulatory Disclosure", "License: MH-2024-7821", "building.columns.fill"),
        ("Code of Conduct for DST Agents", "Version 3.2", "person.badge.shield.checkmark.fill"),
        ("DPDP Consent Framework", "Digital Personal Data Protection Act 2023", "lock.doc.fill"),
    ]

    var body: some View {
        List {
            Section("REGULATORY DOCUMENTS") {
                ForEach(docs, id: \.0) { doc in
                    NavigationLink {
                        PlaceholderView(title: doc.0, icon: doc.2)
                    } label: {
                        HStack(spacing: 14) {
                            RoundedIconView(icon: doc.2, color: Color(red: 0.12, green: 0.35, blue: 0.75))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.0).font(.subheadline).fontWeight(.medium)
                                Text(doc.1).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Terms & Compliance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared Sub-components

struct ToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedIconView(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
    }
}

struct RoundedIconView: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .frame(width: 34, height: 34)
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44)).foregroundStyle(.secondary)
            Text(title)
                .font(.title3).fontWeight(.semibold)
            Text("Content coming soon.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
