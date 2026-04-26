// MARK: - ProfileViewModel.swift
// ViewModel for the Profile tab and all push screens

import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published

    @Published var agent: DSTAgent = MockDSTService.currentAgent()
    @Published var notificationSettings: NotificationSettings = NotificationSettings()
    @Published var isLoading: Bool = false
    @Published var showLogoutConfirm: Bool = false
    @Published var errorMessage: String? = nil

    // Push screen navigation triggers
    @Published var showNotificationSettings: Bool = false
    @Published var showSecurityPin: Bool = false
    @Published var showPrivacy: Bool = false
    @Published var showHelpCenter: Bool = false
    @Published var showContactSupport: Bool = false
    @Published var showTerms: Bool = false

    // MARK: - Computed

    var trustScoreColor: Color {
        switch agent.trustScore {
        case 80...100: return Color(red: 0.12, green: 0.35, blue: 0.75)
        case 60...79:  return .orange
        default:       return .red
        }
    }

    var trustScoreProgress: Double { Double(agent.trustScore) / 100.0 }

    var performanceSummary: String {
        "\(agent.approvalRatePercent)% approval · \(agent.totalLeads) leads"
    }

    var topPerformerText: String {
        "Top Performer — \(agent.zoneRankMonth)"
    }

    var rankText: String {
        "Ranked #\(agent.zoneRank) in \(agent.zone)"
    }

    var settingsItems: [(section: SettingsSection, items: [SettingsItem])] {
        let grouped = Dictionary(grouping: SettingsItem.allCases, by: \.section)
        return [
            (.settings, grouped[.settings] ?? []),
            (.support,  grouped[.support]  ?? [])
        ]
    }

    var footerText: String {
        "DST Agent v\(agent.appVersion) · NBFC License: \(agent.nbfcLicense)"
    }

    // MARK: - Actions

    func loadProfile() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        agent = MockDSTService.currentAgent()
        isLoading = false
    }

    func handleSettingsTap(_ item: SettingsItem) {
        switch item {
        case .notifications:   showNotificationSettings = true
        case .securityPin:     showSecurityPin = true
        case .privacy:         showPrivacy = true
        case .helpCenter:      showHelpCenter = true
        case .contactSupport:  showContactSupport = true
        case .termsCompliance: showTerms = true
        }
    }

    func confirmLogout() { showLogoutConfirm = true }

    func saveNotificationSettings() {
        // TODO: PATCH /api/agent/notification-settings
    }
}
