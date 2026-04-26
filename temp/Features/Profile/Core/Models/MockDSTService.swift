// MARK: - MockDSTService.swift

import Foundation

final class MockDSTService {

    static func currentAgent() -> DSTAgent {
        DSTAgent(
            id: UUID(),
            firstName: "Rajan",
            lastName: "Iyer",
            zone: "West Zone",
            city: "Mumbai",
            agentCode: "DST-MH-2847",
            tier: .senior,
            nbfcLicense: "MH-2024-7821",
            appVersion: "2.4.1",
            avatarColor: "7B8FD4",
            trustScore: 91,
            totalLeads: 48,
            approvalRate: 0.72,
            rejectionRate: 0.14,
            zoneRank: 3,
            zoneRankMonth: "April 2026",
            totalZoneAgents: 84
        )
    }

    static func messageThreads() -> [MessageThread] {
        let agentId = UUID()
        let vikram = ThreadParticipant(id: UUID(), name: "Vikram Malhotra", role: .loanOfficer)
        let ananya = ThreadParticipant(id: UUID(), name: "Ananya Singh", role: .loanOfficer)
        let system = ThreadParticipant(id: UUID(), name: "System Notifications", role: .system)

        let vikramThreadId = UUID()
        let ananyaThreadId = UUID()
        let systemThreadId = UUID()

        return [
            MessageThread(
                id: vikramThreadId,
                participant: vikram,
                messages: [
                    ChatMessage(id: UUID(), threadId: vikramThreadId, senderId: vikram.id, senderRole: .loanOfficer, content: "Hi, I'm reviewing Arjun Mehta's home loan application.", sentAt: todayAt(10, 10), isRead: true, attachmentRef: nil),
                    ChatMessage(id: UUID(), threadId: vikramThreadId, senderId: agentId, senderRole: .dstAgent, content: "Okay, what do you need from me?", sentAt: todayAt(10, 12), isRead: true, attachmentRef: nil),
                    ChatMessage(id: UUID(), threadId: vikramThreadId, senderId: vikram.id, senderRole: .loanOfficer, content: "Can you share the latest 6-month bank statement?", sentAt: todayAt(10, 20), isRead: true, attachmentRef: nil),
                    ChatMessage(id: UUID(), threadId: vikramThreadId, senderId: vikram.id, senderRole: .loanOfficer, content: "Also the salary slip for last 3 months.", sentAt: todayAt(10, 21), isRead: true, attachmentRef: nil),
                    ChatMessage(id: UUID(), threadId: vikramThreadId, senderId: agentId, senderRole: .dstAgent, content: "I'll get those uploaded by this evening.", sentAt: todayAt(10, 23), isRead: true, attachmentRef: nil),
                    ChatMessage(id: UUID(), threadId: vikramThreadId, senderId: vikram.id, senderRole: .loanOfficer, content: "Can you share the latest bank statement for Arjun?", sentAt: todayAt(10, 24), isRead: false, attachmentRef: nil),
                    ChatMessage(id: UUID(), threadId: vikramThreadId, senderId: vikram.id, senderRole: .loanOfficer, content: "It seems the one uploaded earlier was only 3 months.", sentAt: todayAt(10, 25), isRead: false, attachmentRef: nil),
                ],
                linkedApplicationRef: "A002",
                linkedLeadName: "Arjun Mehta"
            ),
            MessageThread(
                id: ananyaThreadId,
                participant: ananya,
                messages: [
                    ChatMessage(id: UUID(), threadId: ananyaThreadId, senderId: ananya.id, senderRole: .loanOfficer, content: "Priya's PAN card is urgent. Can you complete the KYC details today?", sentAt: todayAt(9, 15), isRead: false, attachmentRef: nil),
                ],
                linkedApplicationRef: "A004",
                linkedLeadName: "Priya Sharma"
            ),
            MessageThread(
                id: systemThreadId,
                participant: system,
                messages: [
                    ChatMessage(id: UUID(), threadId: systemThreadId, senderId: system.id, senderRole: .system, content: "Application A001 moved to \"Under Review\".", sentAt: yesterday(9, 0), isRead: true, attachmentRef: nil),
                ],
                linkedApplicationRef: "A001",
                linkedLeadName: "Arjun Mehta"
            ),
        ]
    }

    static func loanOfficerDirectory() -> [ThreadParticipant] {
        [
            ThreadParticipant(id: UUID(), name: "Vikram Malhotra", role: .loanOfficer),
            ThreadParticipant(id: UUID(), name: "Ananya Singh", role: .loanOfficer),
            ThreadParticipant(id: UUID(), name: "Priya S", role: .manager),
        ]
    }

    static func connectableLeads() -> [LeadMessagingConnection] {
        [
            LeadMessagingConnection(id: UUID(), leadName: "Arjun Mehta", applicationRef: "A002", loanType: "Home Loan"),
            LeadMessagingConnection(id: UUID(), leadName: "Priya Sharma", applicationRef: "A004", loanType: "Personal Loan"),
            LeadMessagingConnection(id: UUID(), leadName: "Siddharth Rao", applicationRef: "A007", loanType: "Car Loan"),
        ]
    }

    private static func todayAt(_ hour: Int, _ minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func yesterday(_ hour: Int, _ minute: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
