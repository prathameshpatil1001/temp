import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = ChatListViewModel()
    @State private var showNewChatSheet = false

    private var currentUserID: String {
        sessionStore.borrowerProfileId.isEmpty ? "" : sessionStore.borrowerProfileId
    }

    private var visibleRooms: [ChatRoom] {
        viewModel.filteredChatRooms(currentUserID: currentUserID)
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Support & Chat")
                            .font(.largeTitle).bold()
                        Text("We're here to help with your loan and account.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Search conversations...", text: $viewModel.conversationSearchQuery)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    // Chat List
                    if viewModel.isLoading {
                        ProgressView("Loading conversations...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else if visibleRooms.isEmpty && viewModel.chatRooms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 44))
                                .foregroundColor(.secondary)
                            Text("No conversations yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Start a new conversation to get help with your loan.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, 72)
                    } else if visibleRooms.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No matching conversations")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Try a different name or keyword.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, 72)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(visibleRooms) { room in
                                Button {
                                    router.push(.chatConversation(roomID: room.id))
                                } label: {
                                    let participantName = viewModel.participantName(for: room)
                                    ChatRoomPreviewRow(room: room, participantName: participantName)
                                        .onAppear {
                                            viewModel.loadMoreRoomsIfNeeded(currentRoom: room)
                                        }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            if viewModel.isLoadingMoreRooms {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 110)
            }
            .refreshable {
                viewModel.refresh()
            }

            // Floating New Chat Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        viewModel.userSearchQuery = ""
                        viewModel.eligibleUsers = []
                        showNewChatSheet = true
                    } label: {
                        Image(systemName: "plus.message.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(18)
                            .background(DS.primary)
                            .clipShape(Circle())
                            .shadow(color: .mainBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 86)
                    .sheet(isPresented: $showNewChatSheet) {
                        NewChatSheet(viewModel: viewModel)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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

struct ChatRoomPreviewRow: View {
    let room: ChatRoom
    let participantName: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(DS.primaryLight)
                    .frame(width: 50, height: 50)

                Text(String(participantName.prefix(1)).uppercased())
                    .font(.title3).bold()
                    .foregroundColor(.mainBlue)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(participantName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(room.lastMessageTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Direct Message")
                    .font(.caption).bold()
                    .foregroundColor(.secondary)

                Text(room.lastMessageText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct NewChatSheet: View {
    @ObservedObject var viewModel: ChatListViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: AppRouter
    @State private var selectedUser: ChatUser?
    @State private var isCreating = false
    @State private var sheetSearchQuery = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search by name, email, or phone...", text: $sheetSearchQuery)
                        .onChange(of: sheetSearchQuery) { _, _ in
                            viewModel.searchQuery = sheetSearchQuery
                            viewModel.searchEligibleUsers()
                        }
                    if !sheetSearchQuery.isEmpty {
                        Button {
                            sheetSearchQuery = ""
                            viewModel.searchQuery = ""
                            viewModel.eligibleUsers = []
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if viewModel.eligibleUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text(sheetSearchQuery.isEmpty ? "Search for users to start a conversation" : "No users found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.eligibleUsers) { user in
                            Button {
                                selectedUser = user
                                createRoomAndNavigate(user: user)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(DS.primaryLight)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(user.initials)
                                                .font(.headline)
                                                .foregroundColor(.mainBlue)
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.displayName)
                                            .font(.headline)
                                        Text(user.role)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if isCreating && selectedUser?.id == user.id {
                                        ProgressView()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .disabled(isCreating)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createRoomAndNavigate(user: ChatUser) {
        isCreating = true
        Task {
            do {
                let room = try await viewModel.createRoomWithUser(userID: user.id)
                await MainActor.run {
                    isCreating = false
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        router.push(.chatConversation(roomID: room.id))
                    }
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView().environmentObject(AppRouter())
    }
}

