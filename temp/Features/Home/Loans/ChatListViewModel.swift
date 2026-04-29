// ChatListViewModel.swift
// lms_borrower/Features/Home/Loans
//
// ViewModel for ChatListView - manages chat rooms and user discovery.

import Foundation
import Combine

@MainActor
@available(iOS 18.0, *)
final class ChatListViewModel: ObservableObject {
    @Published var chatRooms: [ChatRoom] = []
    @Published var eligibleUsers: [ChatUser] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var conversationSearchQuery: String = ""
    @Published var userSearchQuery: String = ""
    @Published var searchQuery: String = ""
    @Published var participantNames: [String: String] = [:]
    @Published var hasMoreRooms: Bool = true
    @Published var isLoadingMoreRooms: Bool = false

    private let chatService: ChatServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var currentUserID: String = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var roomsOffset: Int = 0
    private let roomsPageSize: Int = 30

    init(chatService: ChatServiceProtocol = ServiceContainer.chatService) {
        self.chatService = chatService
        self.currentUserID = Self.resolveCurrentUserID()
        loadChatRooms()
    }

    private static func resolveCurrentUserID() -> String {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return ""
        }
        return userID
    }

    // MARK: - Data Loading

    func loadChatRooms() {
        loadChatRooms(reset: true)
    }

    func loadChatRooms(reset: Bool) {
        print("DEBUG: [ChatListVM] loadChatRooms(reset: \(reset))")
        if reset {
            isLoading = true
            roomsOffset = 0
            hasMoreRooms = true
        } else {
            guard hasMoreRooms, !isLoadingMoreRooms else { return }
            isLoadingMoreRooms = true
        }
        errorMessage = nil

        Task {
            do {
                let rooms = try await chatService.listMyChatRooms(limit: roomsPageSize, offset: roomsOffset)
                print("DEBUG: [ChatListVM] Successfully loaded \(rooms.count) rooms")
                let names = await resolveParticipantNames(for: rooms)
                await MainActor.run {
                    if reset {
                        self.chatRooms = rooms
                    } else {
                        self.chatRooms = self.mergeRooms(self.chatRooms + rooms)
                    }
                    self.participantNames.merge(names) { _, new in new }
                    self.roomsOffset += rooms.count
                    self.hasMoreRooms = rooms.count >= self.roomsPageSize
                    self.isLoading = false
                    self.isLoadingMoreRooms = false
                }
            } catch {
                print("DEBUG: [ChatListVM] Failed to load chat rooms: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.isLoadingMoreRooms = false
                }
            }
        }
    }

    func loadMoreRoomsIfNeeded(currentRoom: ChatRoom) {
        guard let lastID = chatRooms.last?.id, currentRoom.id == lastID else { return }
        print("DEBUG: [ChatListVM] loadMoreRoomsIfNeeded triggered")
        loadChatRooms(reset: false)
    }

    func filteredChatRooms(currentUserID: String) -> [ChatRoom] {
        let query = conversationSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return chatRooms
        }
        return chatRooms.filter { room in
            let otherID = room.otherUserID(currentUserID: currentUserID)
            let name = participantNames[otherID]?.lowercased() ?? "user"
            let lastMsg = room.latestMessage?.body.lowercased() ?? ""
            return name.contains(query) || lastMsg.contains(query)
        }
    }

    private func resolveParticipantNames(for rooms: [ChatRoom]) async -> [String: String] {
        var names: [String: String] = [:]
        for room in rooms {
            let otherID = room.otherUserID(currentUserID: currentUserID)
            if names[otherID] == nil {
                names[otherID] = "User"
            }
        }
        do {
            print("DEBUG: [ChatListVM] Resolving participant names...")
            let users = try await chatService.listEligibleUsers(query: "", limit: 100, offset: 0)
            for user in users {
                names[user.id] = user.displayName
            }
            print("DEBUG: [ChatListVM] Resolved names for \(users.count) users")
        } catch {
            print("DEBUG: [ChatListVM] resolveParticipantNames best-effort error: \(error)")
        }
        return names
    }

    // MARK: - Search with debounce

    func searchEligibleUsers() {
        searchDebounceTask?.cancel()
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            eligibleUsers = []
            return
        }

        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                print("DEBUG: [ChatListVM] Searching users with query: \(searchQuery)")
                let users = try await chatService.listEligibleUsers(
                    query: trimmedQuery,
                    limit: 20,
                    offset: 0
                )
                await MainActor.run {
                    self.eligibleUsers = users
                    for user in users {
                        self.participantNames[user.id] = user.displayName
                    }
                    print("DEBUG: [ChatListVM] Search returned \(users.count) users")
                }
            } catch {
                print("DEBUG: [ChatListVM] Search failed: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Room Creation

    func createRoomWithUser(userID: String) async throws -> ChatRoom {
        print("DEBUG: [ChatListVM] createRoomWithUser: \(userID)")
        let room = try await chatService.createOrGetDirectRoom(
            targetUserID: userID
        )
        print("DEBUG: [ChatListVM] Created/Resolved room: \(room.id)")
        if !chatRooms.contains(where: { $0.id == room.id }) {
            chatRooms.insert(room, at: 0)
        }
        if participantNames[userID] == nil {
            if let user = eligibleUsers.first(where: { $0.id == userID }) {
                participantNames[userID] = user.displayName
            }
        }
        return room
    }

    // MARK: - UI Helpers

    func chatPreviewModels() -> [ChatPreviewModel] {
        return chatRooms.map { room in
            let otherUserID = room.otherUserID(currentUserID: currentUserID)
            let participantName = participantNames[otherUserID] ?? "User"
            return ChatPreviewModel(from: room, participantName: participantName, hasUnread: false)
        }
    }

    func participantName(for room: ChatRoom) -> String {
        let otherUserID = room.otherUserID(currentUserID: currentUserID)
        return participantNames[otherUserID] ?? "User"
    }

    func refresh() {
        loadChatRooms()
    }

    private func mergeRooms(_ rooms: [ChatRoom]) -> [ChatRoom] {
        var byID: [String: ChatRoom] = [:]
        for room in rooms {
            byID[room.id] = room
        }
        return byID.values.sorted {
            let l = $0.latestMessage?.createdAt ?? $0.updatedAt
            let r = $1.latestMessage?.createdAt ?? $1.updatedAt
            if l != r { return l > r }
            return $0.id < $1.id
        }
    }
}
