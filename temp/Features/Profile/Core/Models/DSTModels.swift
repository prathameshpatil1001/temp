// MARK: - DSTModels.swift
// Data models for DST Agent App — Profile & Messages tabs

import Foundation
import SwiftUI

struct DSTAgent: Identifiable, Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let zone: String
    let city: String
    let agentCode: String
    let tier: AgentTier
    let nbfcLicense: String
    let appVersion: String
    let avatarColor: String
    let trustScore: Int
    let totalLeads: Int
    let approvalRate: Double
    let rejectionRate: Double
    let zoneRank: Int
    let zoneRankMonth: String
    let totalZoneAgents: Int

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String { "\(firstName.prefix(1))\(lastName.prefix(1))".uppercased() }
    var displayZone: String { "\(zone) — \(city)" }
    var approvalRatePercent: Int { Int(approvalRate * 100) }
    var rejectionRatePercent: Int { Int(rejectionRate * 100) }
    var isTopPerformer: Bool { zoneRank <= 5 }
}

enum AgentTier: String, Codable, CaseIterable {
    case junior = "Junior"
    case senior = "Senior"
    case elite  = "Elite"

    var color: Color {
        switch self {
        case .junior: return .blue
        case .senior: return Color(red: 0.12, green: 0.35, blue: 0.75)
        case .elite:  return Color(red: 0.55, green: 0.35, blue: 0.9)
        }
    }
}

struct NotificationSettings: Codable {
    var pushEnabled: Bool = true
    var smsEnabled: Bool = true
    var leadStatusUpdates: Bool = true
    var documentRequests: Bool = true
    var payoutAlerts: Bool = true
    var marketingMessages: Bool = false
}

struct MessageThread: Identifiable, Codable {
    let id: UUID
    let participant: ThreadParticipant
    let messages: [ChatMessage]
    let linkedApplicationRef: String?
    let linkedLeadName: String?

    var lastMessage: ChatMessage? { messages.last }
    var unreadCount: Int { messages.filter { !$0.isRead && $0.senderRole != .dstAgent }.count }

    var lastMessageTime: String {
        guard let last = lastMessage else { return "" }
        let cal = Calendar.current

        if cal.isDateInToday(last.sentAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: last.sentAt)
        } else if cal.isDateInYesterday(last.sentAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: last.sentAt)
        }
    }
}

struct ThreadParticipant: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let role: ParticipantRole

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

struct LeadMessagingConnection: Identifiable, Equatable {
    let id: UUID
    let leadName: String
    let applicationRef: String
    let loanType: String
}

enum ParticipantRole: String, Codable {
    case loanOfficer = "Loan Officer"
    case manager     = "Manager"
    case system      = "System"
    case dstAgent    = "DST Agent"

    var color: Color {
        switch self {
        case .loanOfficer: return Color(red: 0.12, green: 0.35, blue: 0.75)
        case .manager: return .purple
        case .system: return .secondary
        case .dstAgent: return .primary
        }
    }

    static func from(protoRole: String) -> ParticipantRole {
        switch protoRole.lowercased() {
        case "dst", "dst_agent", "directsales":
            return .dstAgent
        case "officer", "loan_officer":
            return .loanOfficer
        case "manager":
            return .manager
        case "borrower":
            return .loanOfficer // Map borrowers to loan officer role for chat display
        default:
            return .system
        }
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let threadId: UUID
    let senderId: UUID
    let senderRole: ParticipantRole
    let content: String
    let sentAt: Date
    var isRead: Bool
    let attachmentRef: String?

    var isFromMe: Bool { senderRole == .dstAgent }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: sentAt)
    }
}

enum SettingsItem: CaseIterable, Identifiable {
    case notifications
    case securityPin
    case privacy
    case helpCenter
    case contactSupport
    case termsCompliance

    var id: String { title }

    var title: String {
        switch self {
        case .notifications: return "Notifications"
        case .securityPin: return "Security & PIN"
        case .privacy: return "Privacy"
        case .helpCenter: return "Help Center"
        case .contactSupport: return "Contact Support"
        case .termsCompliance: return "Terms & Compliance"
        }
    }

    var subtitle: String {
        switch self {
        case .notifications: return "Push, SMS alerts"
        case .securityPin: return "Biometric, app lock"
        case .privacy: return "Data & consent settings"
        case .helpCenter: return "FAQs, guides, tutorials"
        case .contactSupport: return "Chat or call us"
        case .termsCompliance: return "Regulatory documents"
        }
    }

    var icon: String {
        switch self {
        case .notifications: return "bell"
        case .securityPin: return "lock"
        case .privacy: return "shield"
        case .helpCenter: return "questionmark.circle"
        case .contactSupport: return "phone"
        case .termsCompliance: return "doc.text"
        }
    }

    var section: SettingsSection {
        switch self {
        case .notifications, .securityPin, .privacy: return .settings
        case .helpCenter, .contactSupport, .termsCompliance: return .support
        }
    }
}

enum SettingsSection: String {
    case settings = "SETTINGS"
    case support  = "SUPPORT"
}
