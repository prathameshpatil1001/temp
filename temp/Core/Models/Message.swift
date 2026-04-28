//
//  Message.swift
//  lms_project
//

import Foundation

// MARK: - Conversation (Global — Messages Tab)

struct Conversation: Identifiable, Codable, Hashable {
    let id: String
    var participantName: String
    var participantRole: String
    var participantEmail: String
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
    var isOnline: Bool
}

// MARK: - Message (Global — Messages Tab)

struct Message: Identifiable, Codable, Hashable {
    let id: String
    var conversationId: String
    var senderId: String
    var senderName: String
    var text: String
    var timestamp: Date
    var isFromCurrentUser: Bool
    var attachmentName: String?
}

// MARK: - Application Message (Per-Application Chat)

enum AppMessageType: String, Codable, Hashable {
    case message = "message"
    case managerRemark = "manager_remark"
    case systemNote = "system_note"
}

struct ApplicationMessage: Identifiable, Codable, Hashable {
    let id: String
    var applicationId: String
    var senderId: String
    var senderName: String
    var senderRole: String        // "Loan Officer", "Manager", "Borrower"
    var text: String
    var timestamp: Date
    var type: AppMessageType
    var isFromCurrentUser: Bool
    var attachmentName: String?
}

// MARK: - Quick Reply Template

struct QuickReplyTemplate: Identifiable, Hashable {
    let id: String
    var label: String
    var text: String
    
    static let templates: [QuickReplyTemplate] = [
        QuickReplyTemplate(id: "qr1", label: "Request Docs", text: "Please upload your latest bank statement and salary slip at your earliest convenience."),
        QuickReplyTemplate(id: "qr2", label: "Status Update", text: "Your loan application is currently under review. We will notify you once there is an update."),
        QuickReplyTemplate(id: "qr3", label: "Missing Info", text: "We noticed some information is missing from your application. Could you please provide the following details?"),
        QuickReplyTemplate(id: "qr4", label: "Appointment", text: "We would like to schedule a call to discuss your application. Please let us know your preferred time."),
        QuickReplyTemplate(id: "qr5", label: "Thank You", text: "Thank you for submitting the required documents. We are now processing your application.")
    ]
}
