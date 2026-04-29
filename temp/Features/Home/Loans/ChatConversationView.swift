import SwiftUI
import Combine
import GRPCCore

@MainActor
@available(iOS 18.0, *)
class ChatConversationViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    @Published var participantName: String = "User"
    @Published var participantRole: String = ""
    @Published var hasMoreMessages: Bool = true
    @Published var isLoadingOlderMessages: Bool = false

    private let chatService: ChatServiceProtocol
    private let roomID: String
    private var currentUserID: String = ""
    private var messageStreamTask: Task<Void, Never>?
    private var lastMessageID: String? = nil
    private var messagesOffset: Int = 0
    private let messagePageSize: Int = 50
    private var reconnectAttempt: Int = 0
    private let maxReconnectDelaySeconds: UInt64 = 30

    init(roomID: String, chatService: ChatServiceProtocol = ServiceContainer.chatService) {
        self.roomID = roomID
        self.chatService = chatService
        self.currentUserID = Self.resolveCurrentUserID()
        loadMessages()
        loadParticipantInfo()
        startStreaming()
    }

    private static func resolveCurrentUserID() -> String {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return ""
        }
        return userID
    }

    var isCurrentUser: (String) -> Bool {
        return { [weak self] senderID in
            guard let self else { return false }
            return senderID == self.currentUserID
        }
    }

    deinit {
        messageStreamTask?.cancel()
    }

    // MARK: - Data Loading

    func loadMessages() {
        isLoading = true
        errorMessage = nil
        messagesOffset = 0

        Task {
            do {
                let loadedMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: messagePageSize,
                    offset: 0
                )
                let normalized = normalizeMessages(loadedMessages)
                await MainActor.run {
                    self.messages = normalized
                    self.lastMessageID = normalized.last?.id
                    self.hasMoreMessages = loadedMessages.count >= self.messagePageSize
                    self.messagesOffset = loadedMessages.count
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.handleChatError(error)
                    self.isLoading = false
                }
            }
        }
    }

    func loadOlderMessages() {
        guard !isLoadingOlderMessages, hasMoreMessages else { return }
        isLoadingOlderMessages = true

        Task {
            do {
                let olderMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: messagePageSize,
                    offset: messagesOffset
                )
                await MainActor.run {
                    self.messages = self.normalizeMessages(self.messages + olderMessages)
                    self.lastMessageID = self.messages.last?.id
                    self.messagesOffset += olderMessages.count
                    self.hasMoreMessages = olderMessages.count >= self.messagePageSize
                    self.isLoadingOlderMessages = false
                }
            } catch {
                await MainActor.run {
                    self.handleChatError(error)
                    self.isLoadingOlderMessages = false
                }
            }
        }
    }

    // MARK: - Streaming

    private func startStreaming() {
        print("DEBUG: [ChatConversationVM] startStreaming requested for room: \(roomID)")
        messageStreamTask?.cancel()
        messageStreamTask = Task {
            while !Task.isCancelled {
                print("DEBUG: [ChatConversationVM] Opening stream connection for room: \(roomID)")
                let stream = chatService.subscribeToRoomMessages(roomID: roomID, afterMessageID: lastMessageID)
                do {
                    for try await event in stream {
                        if Task.isCancelled { 
                            print("DEBUG: [ChatConversationVM] Task cancelled, exiting stream loop for room: \(roomID)")
                            break 
                        }

                        if !event.isHeartbeat, let newMessage = event.message {
                            print("DEBUG: [ChatConversationVM] New message received via stream: \(newMessage.id)")
                            await MainActor.run {
                                self.messages = self.normalizeMessages(self.messages + [newMessage])
                                self.lastMessageID = self.messages.last?.id
                            }
                        } else if event.isHeartbeat {
                            print("DEBUG: [ChatConversationVM] Heartbeat received for room: \(roomID)")
                        }
                    }
                    
                    if Task.isCancelled {
                        print("DEBUG: [ChatConversationVM] Stream ended and task is cancelled for room: \(roomID)")
                        break
                    }
                    
                    print("DEBUG: [ChatConversationVM] Stream ended normally (server disconnected). Reconnecting...")
                    await reconcileLatestMessages()
                    reconnectAttempt += 1
                    let delaySeconds = min(UInt64(1 << min(reconnectAttempt, 5)), maxReconnectDelaySeconds)
                    try? await Task.sleep(nanoseconds: (delaySeconds * 1_000_000_000) + UInt64.random(in: 0...500_000_000))
                } catch {
                    if Task.isCancelled { 
                        print("DEBUG: [ChatConversationVM] Stream caught error but task is cancelled: \(error)")
                        break 
                    }
                    print("DEBUG: [ChatConversationVM] Stream error for room \(roomID): \(error)")
                    await MainActor.run {
                        self.handleChatError(error)
                    }
                    
                    print("DEBUG: [ChatConversationVM] Attempting to reconcile messages after error for room: \(roomID)")
                    await reconcileLatestMessages()
                    
                    reconnectAttempt += 1
                    let delaySeconds = min(UInt64(1 << min(reconnectAttempt, 5)), maxReconnectDelaySeconds)
                    print("DEBUG: [ChatConversationVM] Reconnect attempt #\(reconnectAttempt) in \(delaySeconds)s...")
                    try? await Task.sleep(nanoseconds: (delaySeconds * 1_000_000_000) + UInt64.random(in: 0...500_000_000))
                }
            }
        }
    }

    private func reconcileLatestMessages() async {
        do {
            print("DEBUG: [ChatConversationVM] Reconciling latest messages for room: \(roomID)")
            let recent = try await chatService.listRoomMessages(roomID: roomID, limit: messagePageSize, offset: 0)
            await MainActor.run {
                self.messages = self.normalizeMessages(self.messages + recent)
                self.lastMessageID = self.messages.last?.id
                print("DEBUG: [ChatConversationVM] Reconciliation complete. New message count: \(self.messages.count)")
            }
        } catch {
            print("DEBUG: [ChatConversationVM] Reconciliation failed: \(error)")
            await MainActor.run {
                self.handleChatError(error)
            }
        }
    }

    private func normalizeMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var byID: [String: ChatMessage] = [:]
        for message in messages {
            byID[message.id] = message
        }
        return byID.values.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }
    }

    private func loadParticipantInfo() {
        Task {
            do {
                let rooms = try await chatService.listMyChatRooms(limit: 100, offset: 0)
                guard let room = rooms.first(where: { $0.id == roomID }) else { 
                    print("DEBUG: [ChatConversationVM] Could not find room \(roomID) in MyChatRooms")
                    return 
                }
                let otherID = room.otherUserID(currentUserID: currentUserID)
                let users = try await chatService.listEligibleUsers(query: "", limit: 100, offset: 0)
                let participant = users.first(where: { $0.id == otherID })
                await MainActor.run {
                    self.participantName = participant?.displayName ?? "User"
                    self.participantRole = participant?.role.capitalized ?? ""
                }
            } catch {
                print("DEBUG: [ChatConversationVM] loadParticipantInfo best-effort error: \(error)")
            }
        }
    }

    private func handleChatError(_ error: Error) {
        let errorDesc = "\(error)"
        print("DEBUG: [ChatConversationVM] handleChatError: \(errorDesc)")
        
        if let chatError = error as? ChatError, case .unauthenticated = chatError {
            print("DEBUG: [ChatConversationVM] Unauthenticated error detected, posting session expired")
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
        }
        
        // Suppress alert for common stream-interruption network errors that we automatically retry
        if let chatError = error as? ChatError {
            switch chatError {
            case .networkError(let msg):
                print("DEBUG: [ChatConversationVM] Suppressing alert for network error: \(msg)")
                return
            case .underlyingError(let rpc):
                if rpc.code == .unavailable || rpc.code == .deadlineExceeded || rpc.code == .cancelled {
                    print("DEBUG: [ChatConversationVM] Suppressing alert for RPC transient error: \(rpc.code)")
                    return
                }
                // Handle the case where transport throws an unexpected error which is a CancellationError
                if rpc.code == .unknown && (errorDesc.contains("CancellationError") || rpc.message.contains("unexpected error")) {
                    print("DEBUG: [ChatConversationVM] Suppressing alert for unexpected transport cancellation")
                    return
                }
            default:
                break
            }
        }
        
        // Also check raw error string for CancellationError
        if errorDesc.contains("CancellationError") {
            print("DEBUG: [ChatConversationVM] Suppressing alert for raw CancellationError")
            return
        }
        
        errorMessage = error.localizedDescription
    }

    // MARK: - Sending Messages

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = inputText.trimmingCharacters(in: .whitespaces)
        inputText = ""

        Task {
            do {
                let sentMessage = try await chatService.sendMessage(
                    roomID: roomID,
                    body: text,
                    messageType: .text,
                    metadataJSON: nil
                )
                await MainActor.run {
                    self.messages = self.normalizeMessages(self.messages + [sentMessage])
                    self.lastMessageID = self.messages.last?.id
                }
            } catch {
                await MainActor.run {
                    self.handleChatError(error)
                    self.inputText = text
                }
            }
        }
    }

    func refresh() {
        loadMessages()
        startStreaming()
    }
}

struct ChatConversationView: View {
    let roomID: String

    @StateObject private var viewModel: ChatConversationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0

    init(roomID: String) {
        self.roomID = roomID
        _viewModel = StateObject(wrappedValue: ChatConversationViewModel(roomID: roomID))
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading messages...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ChatScrollOffsetReader()
                                    .frame(height: 0)
                                LazyVStack(spacing: 2) {
                                    if viewModel.isLoadingOlderMessages {
                                        ProgressView()
                                            .padding(.vertical, 8)
                                    }
                                    ForEach(viewModel.messages) { message in
                                        ChatBubble(message: message, isFromMe: viewModel.isCurrentUser(message.senderUserID))
                                            .id(message.id)
                                            .onAppear {
                                                if message.id == viewModel.messages.first?.id {
                                                    viewModel.loadOlderMessages()
                                                }
                                            }
                                    }
                                }
                                .padding(.top, topInset + 62)
                                .padding(.bottom, 24)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .coordinateSpace(name: "ChatConversationScroll")
                        .onPreferenceChange(ChatScrollOffsetKey.self) { value in
                            scrollOffset = value
                        }
                        .onAppear {
                            if let last = viewModel.messages.last {
                                DispatchQueue.main.async {
                                    scrollProxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: viewModel.messages.count) { _, _ in
                            if let last = viewModel.messages.last {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    scrollProxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .refreshable {
                            viewModel.refresh()
                        }
                    }
                }

                MessagesNavigationBar(
                    participantName: viewModel.participantName,
                    participantRole: viewModel.participantRole,
                    dismiss: dismiss,
                    scrollOffset: scrollOffset,
                    topInset: topInset
                )
                .ignoresSafeArea(edges: .top)
            }
            .safeAreaInset(edge: .bottom) {
                InputBarView(viewModel: viewModel)
                    .background(.regularMaterial)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Retry") { viewModel.refresh() }
            Button("Dismiss", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct MessagesNavigationBar: View {
    let participantName: String
    let participantRole: String
    let dismiss: DismissAction
    let scrollOffset: CGFloat
    let topInset: CGFloat

    private var collapseProgress: CGFloat {
        min(max(-scrollOffset / 100, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Color(UIColor.systemBackground)
                        .opacity(0.7 * collapseProgress)
                )
                .opacity(0.18 + (0.82 * collapseProgress))

            Divider()
                .opacity(collapseProgress)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.mainBlue)
                }
                .frame(width: 72, alignment: .leading)

                Spacer()

                VStack(spacing: 1) {
                    Circle()
                        .fill(DS.primaryLight)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(String(participantName.prefix(1)))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.mainBlue)
                        )
                        .scaleEffect(0.84 + (0.16 * collapseProgress))

                    VStack(spacing: 1) {
                        Text(participantName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(participantRole.isEmpty ? "Support" : participantRole)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .opacity(0.18 + (0.82 * collapseProgress))
                }
                .frame(maxWidth: .infinity)

                Spacer()

                Color.clear.frame(width: 72)
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset + 6)
            .padding(.bottom, 10)
        }
        .frame(height: topInset + 54)
    }
}


struct ChatBubble: View {
    let message: ChatMessage
    let isFromMe: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 6) {
                if isFromMe {
                    Spacer(minLength: 60)
                } else {
                    Circle()
                        .fill(DS.primaryLight)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text("S")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.mainBlue)
                        )
                }

                Text(message.body)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1.5)
                    .foregroundColor(isFromMe ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 255, alignment: isFromMe ? .trailing : .leading)
                    .background(
                        isFromMe
                            ? DS.primary
                            : Color(UIColor.secondarySystemGroupedBackground)
                    )
                    .clipShape(BubbleShape(isCurrentUser: isFromMe))

                if !isFromMe {
                    Spacer(minLength: 60)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)

            HStack {
                if isFromMe {
                    Spacer()
                }

                Text(message.formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, isFromMe ? 18 : 50)

                if !isFromMe {
                    Spacer()
                }
            }
            .padding(.bottom, 6)
        }
    }
}

struct BubbleShape: Shape {
    let isCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tail: CGFloat = 6
        var path = Path()

        if isCurrentUser {
            path.addRoundedRect(
                in: CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )

            let tailX = rect.maxX - tail
            path.move(to: CGPoint(x: tailX, y: rect.maxY - 10))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: tailX, y: rect.maxY - 4))
        } else {
            path.addRoundedRect(
                in: CGRect(x: tail, y: rect.minY, width: rect.width - tail, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )

            path.move(to: CGPoint(x: tail, y: rect.maxY - 10))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: tail, y: rect.maxY - 4))
        }

        return path
    }
}

struct InputBarView: View {
    @ObservedObject var viewModel: ChatConversationViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                TextField("Message", text: $viewModel.inputText)
                    .font(.system(size: 16))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                if !viewModel.inputText.isEmpty {
                    Button {
                        viewModel.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.mainBlue)
                    }
                    .padding(.trailing, 4)
                }
            }
            .background(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
    }
}

struct ChatScrollOffsetReader: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: ChatScrollOffsetKey.self,
                value: geometry.frame(in: .named("ChatConversationScroll")).minY
            )
        }
    }
}

struct ChatScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
