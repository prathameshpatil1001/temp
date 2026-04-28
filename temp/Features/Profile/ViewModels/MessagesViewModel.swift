// MARK: - MessagesViewModel.swift

import Foundation
import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class MessagesViewModel: ObservableObject {

    @Published var threads: [MessageThread] = []
    @Published var isLoading: Bool = false
    @Published var selectedThread: MessageThread? = nil
    @Published var errorMessage: String? = nil
    @Published var showComposeSheet: Bool = false

    // Backend-driven compose data
    @Published var eligibleParticipants: [ThreadParticipant] = []
    @Published var connectableLeads: [LeadMessagingConnection] = []

    private let chatService: ChatServiceProtocol
    private var chatRooms: [ChatRoom] = []
    private var messageStreamTasks: [String: Task<Void, Never>] = [:]
    private var lastMessageIDByRoom: [String: String] = [:]
    private var currentUserID: String = ""
    private var userRolesCache: [String: String] = [:]
    private let applicationService: ApplicationServiceProtocol
    private var applicationCache: [String: LoanApplication] = [:]
    private var cancellables = Set<AnyCancellable>()

    var totalUnread: Int { threads.reduce(0) { $0 + $1.unreadCount } }

    init(
        chatService: ChatServiceProtocol = ChatService(),
        applicationService: ApplicationServiceProtocol = BackendApplicationService()
    ) {
        self.chatService = chatService
        self.applicationService = applicationService
        self.currentUserID = getCurrentUserID()
        loadApplications()
        Task { await loadThreads(); await loadEligibleUsers() }
    }

    private func loadApplications() {
        applicationService.fetchApplications()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] applications in
                    guard let self else { return }
                    for app in applications {
                        let key = app.id.uuidString
                        self.applicationCache[key] = app
                    }
                    self.connectableLeads = applications.map { app in
                        LeadMessagingConnection(
                            id: app.id.uuidString,
                            leadName: app.name,
                            applicationRef: app.id.uuidString,
                            loanType: app.loanType.rawValue
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func loadEligibleUsers() async {
        do {
            let users = try await chatService.listEligibleUsers(query: "", limit: 50, offset: 0)
            let participants = users.map { user in
                ThreadParticipant(
                    id: user.id,
                    name: user.displayName,
                    role: ParticipantRole.from(protoRole: user.role)
                )
            }
            for user in users {
                userRolesCache[user.id] = user.role
            }
            await MainActor.run {
                self.eligibleParticipants = participants
            }
        } catch {
            // Eligible users list is best-effort; compose sheet falls back gracefully
        }
    }

    private func getCurrentUserID() -> String {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return ""
        }
        return userID
    }

    deinit {
        messageStreamTasks.values.forEach { $0.cancel() }
    }

    func loadThreads() async {
        isLoading = true
        errorMessage = nil

        do {
            let rooms = try await chatService.listMyChatRooms(limit: 50, offset: 0)

            // Cancel streams for rooms no longer present
            let currentRoomIDs = Set(rooms.map(\.id))
            for roomID in messageStreamTasks.keys where !currentRoomIDs.contains(roomID) {
                messageStreamTasks[roomID]?.cancel()
                messageStreamTasks.removeValue(forKey: roomID)
            }

            chatRooms = rooms

            var convertedThreads: [MessageThread] = []
            for room in rooms {
                if let thread = await convertToMessageThread(room: room) {
                    convertedThreads.append(thread)
                }
            }
            threads = convertedThreads.sorted {
                ($0.lastMessage?.sentAt ?? .distantPast) > ($1.lastMessage?.sentAt ?? .distantPast)
            }

            for room in rooms {
                startStreaming(for: room)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func startStreaming(for room: ChatRoom) {
        // Cancel existing stream for this room before starting a new one
        messageStreamTasks[room.id]?.cancel()

        let afterMessageID = lastMessageIDByRoom[room.id]
        let task = Task {
            let stream = chatService.subscribeToRoomMessages(roomID: room.id, afterMessageID: afterMessageID)

            do {
                for try await event in stream {
                    if Task.isCancelled { break }

                    if !event.isHeartbeat, let newMessage = event.message {
                        lastMessageIDByRoom[room.id] = newMessage.id

                        await MainActor.run {
                            if let idx = self.chatRooms.firstIndex(where: { $0.id == room.id }) {
                                var updatedRoom = self.chatRooms[idx]
                                self.chatRooms[idx] = ChatRoom(
                                    id: updatedRoom.id,
                                    roomType: updatedRoom.roomType,
                                    userAID: updatedRoom.userAID,
                                    userBID: updatedRoom.userBID,
                                    createdByUserID: updatedRoom.createdByUserID,
                                    contextApplicationID: updatedRoom.contextApplicationID,
                                    createdAt: updatedRoom.createdAt,
                                    updatedAt: Date(),
                                    latestMessage: newMessage
                                )

                                if let threadIdx = self.threads.firstIndex(where: { $0.id == room.id }) {
                                    let newChatMessage = self.convertToChatMessage(protoMessage: newMessage)
                                    var updatedThread = self.threads[threadIdx]
                                    updatedThread = MessageThread(
                                        id: updatedThread.id,
                                        participant: updatedThread.participant,
                                        messages: updatedThread.messages + [newChatMessage],
                                        linkedApplicationRef: updatedThread.linkedApplicationRef,
                                        linkedLeadName: updatedThread.linkedLeadName
                                    )
                                    self.threads[threadIdx] = updatedThread
                                    self.moveThreadToTop(updatedThread.id)
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        messageStreamTasks[room.id] = task
    }

    private func convertToMessageThread(room: ChatRoom) async -> MessageThread? {
        let participantID = room.otherUserID(currentUserID: currentUserID)
        let participantName: String
        let participantRole: ParticipantRole

        if let cached = eligibleParticipants.first(where: { $0.id == participantID }) {
            participantName = cached.name
            participantRole = cached.role
        } else {
            participantName = "User"
            participantRole = .loanOfficer
        }
        let participant = ThreadParticipant(id: participantID, name: participantName, role: participantRole)

        var messages: [ChatMessage] = []
        do {
            let protoMessages = try await chatService.listRoomMessages(
                roomID: room.id,
                limit: 50,
                offset: 0
            )
            messages = protoMessages.map { proto in
                let msg = convertToChatMessage(protoMessage: proto)
                lastMessageIDByRoom[room.id] = proto.id
                return msg
            }
        } catch {
            // Continue with empty messages on error
        }

        var leadName: String? = nil
        if let appID = room.contextApplicationID {
            leadName = applicationCache[appID]?.name
        }

        return MessageThread(
            id: room.id,
            participant: participant,
            messages: messages,
            linkedApplicationRef: room.contextApplicationID,
            linkedLeadName: leadName
        )
    }

    private func convertToChatMessage(protoMessage: ChatDomainMessage) -> ChatMessage {
        let senderRole: ParticipantRole
        if let cachedRole = userRolesCache[protoMessage.senderUserID] {
            senderRole = ParticipantRole.from(protoRole: cachedRole)
        } else {
            senderRole = protoMessage.senderUserID == currentUserID ? .dstAgent : .loanOfficer
        }

        return ChatMessage(
            id: protoMessage.id,
            threadId: protoMessage.roomID,
            senderId: protoMessage.senderUserID,
            senderRole: senderRole,
            content: protoMessage.body,
            sentAt: protoMessage.createdAt,
            isRead: true,
            attachmentRef: protoMessage.metadataJSON.isEmpty ? nil : protoMessage.metadataJSON
        )
    }

    func selectThread(_ thread: MessageThread) {
        selectedThread = threads.first(where: { $0.id == thread.id }) ?? thread
        markThreadAsRead(thread.id)
    }

    func markThreadAsRead(_ threadId: String) {
        guard let idx = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let updated = threads[idx]

        let readMessages = updated.messages.map { message -> ChatMessage in
            var copy = message
            if copy.senderRole != .dstAgent {
                copy.isRead = true
            }
            return copy
        }

        threads[idx] = MessageThread(
            id: updated.id,
            participant: updated.participant,
            messages: readMessages,
            linkedApplicationRef: updated.linkedApplicationRef,
            linkedLeadName: updated.linkedLeadName
        )
        selectedThread = threads[idx]
    }

    func updateThread(_ threadId: String, messages: [ChatMessage]) {
        guard let idx = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let updated = threads[idx]

        threads[idx] = MessageThread(
            id: updated.id,
            participant: updated.participant,
            messages: messages,
            linkedApplicationRef: updated.linkedApplicationRef,
            linkedLeadName: updated.linkedLeadName
        )

        moveThreadToTop(threadId)

        if selectedThread?.id == threadId {
            selectedThread = threads.first(where: { $0.id == threadId })
        }
    }

    func createThread(lead: LeadMessagingConnection?, participant: ThreadParticipant, openingMessage: String) async {
        do {
            let contextAppID: String?
            if participant.role == .borrower {
                contextAppID = lead?.applicationRef
            } else {
                contextAppID = nil
            }
            let room = try await chatService.createOrGetDirectRoom(
                targetUserID: participant.id,
                contextApplicationID: contextAppID
            )

            // Avoid duplicate thread insertion
            if threads.contains(where: { $0.id == room.id }) {
                await MainActor.run {
                    if let existing = threads.first(where: { $0.id == room.id }) {
                        selectedThread = existing
                    }
                }
                return
            }

            if var thread = await convertToMessageThread(room: room) {
                let trimmed = openingMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    do {
                        let sentMessage = try await chatService.sendMessage(
                            roomID: room.id,
                            body: trimmed,
                            messageType: .text,
                            metadataJSON: nil
                        )
                        let chatMsg = convertToChatMessage(protoMessage: sentMessage)
                        thread = MessageThread(
                            id: thread.id,
                            participant: thread.participant,
                            messages: thread.messages + [chatMsg],
                            linkedApplicationRef: thread.linkedApplicationRef,
                            linkedLeadName: lead?.leadName ?? thread.linkedLeadName
                        )
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Room created but message failed: \(error.localizedDescription)"
                        }
                    }
                }

                await MainActor.run {
                    self.threads.insert(thread, at: 0)
                    self.chatRooms.append(room)
                }
                startStreaming(for: room)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func moveThreadToTop(_ threadId: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadId }) else { return }
        let thread = threads.remove(at: index)
        threads.insert(thread, at: 0)
    }

    func refresh() {
        Task { await loadThreads() }
    }
}

@MainActor
@available(iOS 18.0, *)
final class ChatViewModel: ObservableObject {

    let thread: MessageThread
    private let onMessagesUpdated: ([ChatMessage]) -> Void
    private let chatService: ChatServiceProtocol
    let roomID: String
    private var messageStreamTask: Task<Void, Never>?
    private var currentUserID: String = ""
    private var userRolesCache: [String: String] = [:]
    private var lastMessageID: String? = nil
    private var messageOffset: Int = 0
    private let messagePageSize: Int = 50
    @Published var hasMoreMessages: Bool = true

    @Published var messages: [ChatMessage]
    @Published var draftText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let agentId = "agent-dst"

    init(thread: MessageThread, chatService: ChatServiceProtocol = ChatService(), onMessagesUpdated: @escaping ([ChatMessage]) -> Void = { _ in }) {
        self.thread = thread
        self.chatService = chatService
        self.onMessagesUpdated = onMessagesUpdated
        self.messages = thread.messages
        self.roomID = thread.id
        self.currentUserID = getCurrentUserID()
        loadMessages()
        startStreaming()
    }

    private func getCurrentUserID() -> String {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return ""
        }
        return userID
    }

    deinit {
        messageStreamTask?.cancel()
    }

    var navigationTitle: String { thread.participant.name }
    var navigationSubtitle: String { thread.participant.role.rawValue }
    var linkedLeadSummary: String? {
        guard let lead = thread.linkedLeadName, let ref = thread.linkedApplicationRef else { return nil }
        return "\(lead) · \(ref)"
    }

    var canSend: Bool { !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var groupedMessages: [(date: String, messages: [ChatMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { message -> String in
            if calendar.isDateInToday(message.sentAt) { return "Today" }
            if calendar.isDateInYesterday(message.sentAt) { return "Yesterday" }
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: message.sentAt)
        }

        let order = ["Yesterday", "Today"]
        let sorted = grouped.sorted { a, b in
            let ai = order.firstIndex(of: a.key) ?? -1
            let bi = order.firstIndex(of: b.key) ?? -1
            if ai >= 0 && bi >= 0 { return ai < bi }
            if ai >= 0 { return false }
            if bi >= 0 { return true }
            return a.key < b.key
        }

        return sorted.map { (date: $0.key, messages: $0.value.sorted { $0.sentAt < $1.sentAt }) }
    }

    private func loadMessages() {
        isLoading = true
        errorMessage = nil
        messageOffset = 0

        Task {
            do {
                let protoMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: messagePageSize,
                    offset: 0
                )
                let convertedMessages = protoMessages.map { proto in
                    convertToChatMessage(protoMessage: proto)
                }
                if let lastMsg = protoMessages.last {
                    lastMessageID = lastMsg.id
                }
                hasMoreMessages = protoMessages.count >= messagePageSize
                messageOffset = protoMessages.count
                await MainActor.run {
                    self.messages = convertedMessages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func loadOlderMessages() {
        guard !isLoading && hasMoreMessages else { return }
        isLoading = true

        Task {
            do {
                let protoMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: messagePageSize,
                    offset: messageOffset
                )
                let convertedMessages = protoMessages.map { proto in
                    convertToChatMessage(protoMessage: proto)
                }
                hasMoreMessages = protoMessages.count >= messagePageSize
                messageOffset += protoMessages.count
                await MainActor.run {
                    // Prepend older messages, deduping by ID
                    let existingIDs = Set(self.messages.map(\.id))
                    let newMessages = convertedMessages.filter { !existingIDs.contains($0.id) }
                    self.messages = newMessages + self.messages
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func startStreaming() {
        messageStreamTask?.cancel()
        messageStreamTask = Task {
            let stream = chatService.subscribeToRoomMessages(roomID: roomID, afterMessageID: lastMessageID)

            do {
                for try await event in stream {
                    if Task.isCancelled { break }

                    if !event.isHeartbeat, let newMessage = event.message {
                        lastMessageID = newMessage.id
                        await MainActor.run {
                            let convertedMessage = self.convertToChatMessage(protoMessage: newMessage)
                            if !self.messages.contains(where: { $0.id == convertedMessage.id }) {
                                self.messages.append(convertedMessage)
                                self.onMessagesUpdated(self.messages)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func convertToChatMessage(protoMessage: ChatDomainMessage) -> ChatMessage {
        let senderRole: ParticipantRole
        if let cachedRole = userRolesCache[protoMessage.senderUserID] {
            senderRole = ParticipantRole.from(protoRole: cachedRole)
        } else {
            senderRole = protoMessage.senderUserID == currentUserID ? .dstAgent : .loanOfficer
        }

        return ChatMessage(
            id: protoMessage.id,
            threadId: protoMessage.roomID,
            senderId: protoMessage.senderUserID,
            senderRole: senderRole,
            content: protoMessage.body,
            sentAt: protoMessage.createdAt,
            isRead: true,
            attachmentRef: protoMessage.metadataJSON.isEmpty ? nil : protoMessage.metadataJSON
        )
    }

    func sendMessage() {
        guard canSend else { return }
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        draftText = ""

        Task {
            do {
                let sentMessage = try await chatService.sendMessage(
                    roomID: roomID,
                    body: text,
                    messageType: .text,
                    metadataJSON: nil
                )
                let convertedMessage = convertToChatMessage(protoMessage: sentMessage)
                await MainActor.run {
                    if !self.messages.contains(where: { $0.id == convertedMessage.id }) {
                        self.messages.append(convertedMessage)
                        self.onMessagesUpdated(self.messages)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.draftText = text
                }
            }
        }
    }

    func sendAttachment(fileName: String) {
        Task {
            do {
                let sentMessage = try await chatService.sendMessage(
                    roomID: roomID,
                    body: fileName,
                    messageType: .text,
                    metadataJSON: "{\"attachment\": \"\(fileName)\"}"
                )
                let convertedMessage = convertToChatMessage(protoMessage: sentMessage)
                await MainActor.run {
                    if !self.messages.contains(where: { $0.id == convertedMessage.id }) {
                        self.messages.append(convertedMessage)
                        self.onMessagesUpdated(self.messages)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refresh() {
        loadMessages()
    }
}