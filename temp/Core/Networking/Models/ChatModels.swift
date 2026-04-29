// ChatModels.swift
// lms_borrower/Networking/Models
//
// Domain models for Chat functionality, mapping from proto to app-specific models.

import Foundation

// MARK: - ChatUser

public struct ChatUser: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let email: String
    public let phone: String
    public let role: String
    public let branchID: String?

    public init(
        id: String,
        name: String,
        email: String,
        phone: String,
        role: String,
        branchID: String?
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.role = role
        self.branchID = branchID
    }

    // Mapper from proto
    public init(from proto: Chat_V1_ChatUser) {
        self.id = proto.userID
        self.name = proto.name
        self.email = proto.email
        self.phone = proto.phone
        self.role = proto.role
        self.branchID = proto.branchID.isEmpty ? nil : proto.branchID
    }

    // Display name fallback
    public var displayName: String {
        name.isEmpty ? email : name
    }

    // Initials for avatar
    public var initials: String {
        let components = name.components(separatedBy: " ")
        return components.map { String($0.prefix(1)) }.joined()
    }
}

// MARK: - ChatRoomType

public enum ChatRoomType: String, Equatable {
    case unspecified = "CHAT_ROOM_TYPE_UNSPECIFIED"
    case direct = "CHAT_ROOM_TYPE_DIRECT"

    public init(from proto: Chat_V1_ChatRoomType) {
        switch proto {
        case .unspecified:
            self = .unspecified
        case .direct:
            self = .direct
        case .UNRECOGNIZED:
            self = .unspecified
        }
    }

    public var protoValue: Chat_V1_ChatRoomType {
        switch self {
        case .unspecified:
            return .unspecified
        case .direct:
            return .direct
        }
    }
}

// MARK: - ChatMessageType

public enum ChatMessageType: String, Equatable {
    case unspecified = "CHAT_MESSAGE_TYPE_UNSPECIFIED"
    case text = "CHAT_MESSAGE_TYPE_TEXT"

    public init(from proto: Chat_V1_ChatMessageType) {
        switch proto {
        case .unspecified:
            self = .unspecified
        case .text:
            self = .text
        case .UNRECOGNIZED:
            self = .unspecified
        }
    }

    public var protoValue: Chat_V1_ChatMessageType {
        switch self {
        case .unspecified:
            return .unspecified
        case .text:
            return .text
        }
    }
}

// MARK: - ChatMessage

public struct ChatMessage: Identifiable, Equatable {
    public let id: String
    public let roomID: String
    public let senderUserID: String
    public let messageType: ChatMessageType
    public let body: String
    public let metadataJSON: String
    public let createdAt: Date

    public init(
        id: String,
        roomID: String,
        senderUserID: String,
        messageType: ChatMessageType,
        body: String,
        metadataJSON: String,
        createdAt: Date
    ) {
        self.id = id
        self.roomID = roomID
        self.senderUserID = senderUserID
        self.messageType = messageType
        self.body = body
        self.metadataJSON = metadataJSON
        self.createdAt = createdAt
    }

    // Mapper from proto
    public init(from proto: Chat_V1_ChatMessage) {
        self.id = proto.id
        self.roomID = proto.roomID
        self.senderUserID = proto.senderUserID
        self.messageType = ChatMessageType(from: proto.messageType)
        self.body = proto.body
        self.metadataJSON = proto.metadataJson
        self.createdAt = ISO8601DateFormatter().date(from: proto.createdAt) ?? Date()
    }

    // Check if message is from current user
    public func isFromCurrentUser(currentUserID: String) -> Bool {
        senderUserID == currentUserID
    }

    // Formatted time for display
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: createdAt)
    }

    // Formatted date for grouping
    public var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(createdAt) {
            return "Today"
        } else if calendar.isDateInYesterday(createdAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: createdAt)
        }
    }
}

// MARK: - ChatRoom

public struct ChatRoom: Identifiable, Equatable {
    public let id: String
    public let roomType: ChatRoomType
    public let userAID: String
    public let userBID: String
    public let createdByUserID: String
    public let createdAt: Date
    public let updatedAt: Date
    public let latestMessage: ChatMessage?

    public init(
        id: String,
        roomType: ChatRoomType,
        userAID: String,
        userBID: String,
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date,
        latestMessage: ChatMessage?
    ) {
        self.id = id
        self.roomType = roomType
        self.userAID = userAID
        self.userBID = userBID
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.latestMessage = latestMessage
    }

    // Mapper from proto
    public init(from proto: Chat_V1_ChatRoom) {
        self.id = proto.id
        self.roomType = ChatRoomType(from: proto.roomType)
        self.userAID = proto.userAID
        self.userBID = proto.userBID
        self.createdByUserID = proto.createdByUserID
        self.createdAt = ISO8601DateFormatter().date(from: proto.createdAt) ?? Date()
        self.updatedAt = ISO8601DateFormatter().date(from: proto.updatedAt) ?? Date()
        self.latestMessage = proto.hasLatestMessage ? ChatMessage(from: proto.latestMessage) : nil
    }

    // Get the other user's ID (not the current user)
    public func otherUserID(currentUserID: String) -> String {
        userAID == currentUserID ? userBID : userAID
    }

    // Get last message text for preview
    public var lastMessageText: String {
        latestMessage?.body ?? "No messages yet"
    }

    // Get formatted time for last message
    public var lastMessageTime: String {
        guard let latestMessage = latestMessage else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .short
            return formatter.string(from: updatedAt)
        }
        return latestMessage.formattedTime
    }
}

// MARK: - ChatMessageEvent

public enum ChatMessageEvent: Equatable {
    case message(ChatMessage)
    case heartbeat(String)

    public init(from proto: Chat_V1_ChatMessageEvent) {
        switch proto.payload {
        case .message(let msg):
            self = .message(ChatMessage(from: msg))
        case .heartbeat(let beat):
            self = .heartbeat(beat)
        case nil:
            self = .heartbeat("")
        }
    }

    public var isHeartbeat: Bool {
        if case .heartbeat = self {
            return true
        }
        return false
    }

    public var message: ChatMessage? {
        if case .message(let msg) = self {
            return msg
        }
        return nil
    }
}

// MARK: - ChatPreviewModel (UI Model)

// This is the model used by the existing ChatListView UI
// We'll map from ChatRoom to this for backward compatibility
public struct ChatPreviewModel: Identifiable, Equatable {
    public let id: String
    public let agentName: String
    public let topic: String
    public let lastMessage: String
    public let time: String
    public let hasUnread: Bool
    public let isClosed: Bool
    public let roomID: String

    public init(
        id: String,
        agentName: String,
        topic: String,
        lastMessage: String,
        time: String,
        hasUnread: Bool,
        isClosed: Bool,
        roomID: String
    ) {
        self.id = id
        self.agentName = agentName
        self.topic = topic
        self.lastMessage = lastMessage
        self.time = time
        self.hasUnread = hasUnread
        self.isClosed = isClosed
        self.roomID = roomID
    }

    // Create from ChatRoom with participant info
    public init(from room: ChatRoom, participantName: String, hasUnread: Bool = false) {
        self.id = room.id
        self.agentName = participantName
        self.topic = "General"
        self.lastMessage = room.lastMessageText
        self.time = room.lastMessageTime
        self.hasUnread = hasUnread
        self.isClosed = false
        self.roomID = room.id
    }
}
