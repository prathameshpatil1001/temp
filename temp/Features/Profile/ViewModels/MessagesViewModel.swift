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

    private let chatService: ChatServiceProtocol
    private var chatRooms: [ChatRoom] = []
    private var messageStreamTasks: [String: Task<Void, Never>] = [:]
    private var currentUserID: String = ""
    private var userRolesCache: [String: String] = [:] // Cache for user roles
    private let applicationService: ApplicationServiceProtocol = MockApplicationService.shared
    private var applicationCache: [String: LoanApplication] = [:] // Cache for applications by ID
    private var cancellables = Set<AnyCancellable>()

    // TODO: Replace with real data from loan service
    let officerDirectory: [ThreadParticipant] = MockDSTService.loanOfficerDirectory()
    let connectableLeads: [LeadMessagingConnection] = MockDSTService.connectableLeads()

    var totalUnread: Int { threads.reduce(0) { $0 + $1.unreadCount } }
    var pendingConnectionCount: Int { max(connectableLeads.count - threads.filter { $0.participant.role != .system }.count, 0) }

    init(chatService: ChatServiceProtocol = ChatService()) {
        self.chatService = chatService
        self.currentUserID = getCurrentUserID()
        loadApplications()
        Task { await loadThreads() }
    }

    private func loadApplications() {
        applicationService.fetchApplications()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { applications in
                    for app in applications {
                        if let appID = app.leadId?.uuidString {
                            self.applicationCache[appID] = app
                        }
                    }
                }
            )
            .store(in: &cancellables)
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
            chatRooms = rooms

            // Convert ChatRooms to MessageThreads for UI compatibility
            var convertedThreads: [MessageThread] = []
            for room in rooms {
                if let thread = await convertToMessageThread(room: room) {
                    convertedThreads.append(thread)
                }
            }
            threads = convertedThreads.sorted {
                ($0.lastMessage?.sentAt ?? .distantPast) > ($1.lastMessage?.sentAt ?? .distantPast)
            }

            // Start streaming for each room
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
        let task = Task {
            let stream = chatService.subscribeToRoomMessages(roomID: room.id, afterMessageID: nil)

            do {
                for try await event in stream {
                    if Task.isCancelled { break }

                    if !event.isHeartbeat, let newMessage = event.message {
                        await MainActor.run {
                            // Update the chat room with new message
                            if let idx = self.chatRooms.firstIndex(where: { $0.id == room.id }) {
                                var updatedRoom = self.chatRooms[idx]
                                // Update latest message
                                let updatedMessage = newMessage
                                self.chatRooms[idx] = ChatRoom(
                                    id: updatedRoom.id,
                                    roomType: updatedRoom.roomType,
                                    userAID: updatedRoom.userAID,
                                    userBID: updatedRoom.userBID,
                                    createdByUserID: updatedRoom.createdByUserID,
                                    contextApplicationID: updatedRoom.contextApplicationID,
                                    createdAt: updatedRoom.createdAt,
                                    updatedAt: Date(),
                                    latestMessage: updatedMessage
                                )

                                // Update thread
                                if let threadIdx = self.threads.firstIndex(where: { $0.id == UUID(uuidString: room.id) ?? UUID() }) {
                                    let newChatMessage = self.convertToChatMessage(protoMessage: newMessage, threadId: self.threads[threadIdx].id)
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
        guard let roomUUID = UUID(uuidString: room.id) else { return nil }

        // Find participant info from officer directory or create placeholder
        let participant = officerDirectory.first { $0.id.uuidString == room.userAID || $0.id.uuidString == room.userBID }
            ?? ThreadParticipant(
                id: UUID(uuidString: room.otherUserID(currentUserID: currentUserID)) ?? UUID(),
                name: "User",
                role: .loanOfficer
            )

        // Load messages for this room
        var messages: [ChatMessage] = []
        do {
            let protoMessages = try await chatService.listRoomMessages(
                roomID: room.id,
                limit: 50,
                offset: 0
            )
            messages = protoMessages.map { proto in
                convertToChatMessage(protoMessage: proto, threadId: roomUUID)
            }
        } catch {
            // Continue with empty messages on error
        }

        // Get lead name from application cache
        var leadName: String? = nil
        if let appID = room.contextApplicationID {
            leadName = applicationCache[appID]?.name
        }

        return MessageThread(
            id: roomUUID,
            participant: participant,
            messages: messages,
            linkedApplicationRef: room.contextApplicationID,
            linkedLeadName: leadName
        )
    }

    private func convertToChatMessage(protoMessage: ChatDomainMessage, threadId: UUID) -> ChatMessage {
        // Determine sender role - check cache first, then use default
        let senderRole: ParticipantRole
        if let cachedRole = self.userRolesCache[protoMessage.senderUserID] {
            senderRole = ParticipantRole.from(protoRole: cachedRole)
        } else {
            // For now, default to dstAgent if it's the current user, otherwise loanOfficer
            senderRole = protoMessage.senderUserID == self.currentUserID ? .dstAgent : .loanOfficer
        }

        return ChatMessage(
            id: UUID(uuidString: protoMessage.id) ?? UUID(),
            threadId: threadId,
            senderId: UUID(uuidString: protoMessage.senderUserID) ?? UUID(),
            senderRole: senderRole,
            content: protoMessage.body,
            sentAt: protoMessage.createdAt,
            isRead: true,
            attachmentRef: nil
        )
    }

    func selectThread(_ thread: MessageThread) {
        selectedThread = threads.first(where: { $0.id == thread.id }) ?? thread
        markThreadAsRead(thread.id)
    }

    func markThreadAsRead(_ threadId: UUID) {
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

    func updateThread(_ threadId: UUID, messages: [ChatMessage]) {
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

    func createThread(lead: LeadMessagingConnection, participant: ThreadParticipant, openingMessage: String) {
        Task {
            do {
                let room = try await chatService.createOrGetDirectRoom(
                    targetUserID: participant.id.uuidString,
                    contextApplicationID: lead.applicationRef
                )

                if let messageThread = await convertToMessageThread(room: room) {
                    await MainActor.run {
                        // Add opening message if provided
                        var finalThread = messageThread
                        let trimmed = openingMessage.trimmingCharacters(in: .whitespacesAndNewlines)

                        if !trimmed.isEmpty {
                            let newMessage = ChatMessage(
                                id: UUID(),
                                threadId: finalThread.id,
                                senderId: UUID(),
                                senderRole: .dstAgent,
                                content: trimmed,
                                sentAt: Date(),
                                isRead: true,
                                attachmentRef: nil
                            )
                            finalThread = MessageThread(
                                id: finalThread.id,
                                participant: finalThread.participant,
                                messages: finalThread.messages + [newMessage],
                                linkedApplicationRef: finalThread.linkedApplicationRef,
                                linkedLeadName: lead.leadName
                            )

                            // Send the message via chat service
                            Task {
                                try? await chatService.sendMessage(
                                    roomID: room.id,
                                    body: trimmed,
                                    messageType: .text,
                                    metadataJSON: nil
                                )
                            }
                        }

                        threads.insert(finalThread, at: 0)
                        chatRooms.append(room)
                        startStreaming(for: room)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func moveThreadToTop(_ threadId: UUID) {
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
    private let roomID: String
    private var messageStreamTask: Task<Void, Never>?
    private var currentUserID: String = ""
    private var userRolesCache: [String: String] = [:]

    @Published var messages: [ChatMessage]
    @Published var draftText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let agentId = UUID()

    init(thread: MessageThread, chatService: ChatServiceProtocol = ChatService(), onMessagesUpdated: @escaping ([ChatMessage]) -> Void = { _ in }) {
        self.thread = thread
        self.chatService = chatService
        self.onMessagesUpdated = onMessagesUpdated
        self.messages = thread.messages
        self.roomID = thread.id.uuidString
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

        Task {
            do {
                let protoMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: 100,
                    offset: 0
                )
                let convertedMessages = protoMessages.map { proto in
                    convertToChatMessage(protoMessage: proto, threadId: thread.id)
                }
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

    private func startStreaming() {
        messageStreamTask = Task {
            let stream = chatService.subscribeToRoomMessages(roomID: roomID, afterMessageID: nil)

            do {
                for try await event in stream {
                    if Task.isCancelled { break }

                    if !event.isHeartbeat, let newMessage = event.message {
                        await MainActor.run {
                            let convertedMessage = self.convertToChatMessage(protoMessage: newMessage, threadId: self.thread.id)
                            if !self.messages.contains(where: { $0.id == convertedMessage.id }) {
                                self.messages.append(convertedMessage)
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

    private func convertToChatMessage(protoMessage: ChatDomainMessage, threadId: UUID) -> ChatMessage {
        // Determine sender role - check cache first, then use default
        let senderRole: ParticipantRole
        if let cachedRole = self.userRolesCache[protoMessage.senderUserID] {
            senderRole = ParticipantRole.from(protoRole: cachedRole)
        } else {
            // For now, default to dstAgent if it's the current user, otherwise loanOfficer
            senderRole = protoMessage.senderUserID == self.currentUserID ? .dstAgent : .loanOfficer
        }

        return ChatMessage(
            id: UUID(uuidString: protoMessage.id) ?? UUID(),
            threadId: threadId,
            senderId: UUID(uuidString: protoMessage.senderUserID) ?? UUID(),
            senderRole: senderRole,
            content: protoMessage.body,
            sentAt: protoMessage.createdAt,
            isRead: true,
            attachmentRef: nil
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
                let convertedMessage = convertToChatMessage(protoMessage: sentMessage, threadId: thread.id)
                await MainActor.run {
                    if !self.messages.contains(where: { $0.id == convertedMessage.id }) {
                        self.messages.append(convertedMessage)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.draftText = text // Restore text on error
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
                let convertedMessage = convertToChatMessage(protoMessage: sentMessage, threadId: thread.id)
                await MainActor.run {
                    if !self.messages.contains(where: { $0.id == convertedMessage.id }) {
                        self.messages.append(convertedMessage)
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
