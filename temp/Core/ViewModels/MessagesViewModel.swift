//
//  MessagesViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedConversation: Conversation? = nil
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    
    // Add User
    @Published var showAddUser = false
    @Published var addUserInput = ""
    @Published var addUserError: String? = nil
    @Published var addUserSuccess = false
    
    private let dataService = MockDataService.shared
    
    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    // MARK: - Load Data
    
    func loadConversations() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.conversations = self.dataService.fetchConversations()
            if self.selectedConversation == nil {
                self.selectedConversation = self.conversations.first
            }
            self.loadMessages()
            self.isLoading = false
        }
    }
    
    func selectConversation(_ conversation: Conversation) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedConversation = conversation
            // Mark as read
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index].unreadCount = 0
            }
        }
        loadMessages()
    }
    
    func loadMessages() {
        guard let conversation = selectedConversation else { return }
        messages = dataService.fetchMessages(conversationId: conversation.id)
    }
    
    // MARK: - Send Message
    
    func sendMessage() {
        sendMessage(text: messageText)
    }
    
    func sendMessage(text: String = "", attachmentName: String? = nil) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let conversation = selectedConversation,
              !trimmedText.isEmpty || attachmentName != nil else { return }
        
        let newMessage = Message(
            id: "MSG-\(UUID().uuidString.prefix(6))",
            conversationId: conversation.id,
            senderId: "LO-001",
            senderName: "Amit Singh",
            text: trimmedText,
            timestamp: Date(),
            isFromCurrentUser: true,
            attachmentName: attachmentName
        )
        
        withAnimation {
            messages.append(newMessage)
        }
        
        // Update last message in conversation
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            if let attachmentName {
                conversations[index].lastMessage = trimmedText.isEmpty ? attachmentName : "\(trimmedText) · \(attachmentName)"
            } else {
                conversations[index].lastMessage = trimmedText
            }
            conversations[index].lastMessageTime = Date()
        }
        
        messageText = ""
    }
    
    func sendQuickReply(_ template: QuickReplyTemplate) {
        messageText = template.text
        sendMessage()
    }
    
    // MARK: - Add User to Chat
    
    func submitAddUser() {
        addUserError = nil
        let query = addUserInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            addUserError = "Please enter an email or phone number."
            return
        }
        
        // Check if conversation already exists
        let alreadyExists = conversations.contains {
            $0.participantEmail.lowercased() == query.lowercased()
        }
        if alreadyExists {
            addUserError = "A conversation with this user already exists."
            return
        }
        
        // Attempt to find user in mock data
        if let user = dataService.findUser(emailOrPhone: query) {
            let newConversation = Conversation(
                id: "CONV-\(UUID().uuidString.prefix(6))",
                participantName: user.name,
                participantRole: user.role.displayName,
                participantEmail: user.email,
                lastMessage: "New conversation started.",
                lastMessageTime: Date(),
                unreadCount: 0,
                isOnline: false
            )
            withAnimation {
                conversations.insert(newConversation, at: 0)
                selectedConversation = newConversation
                messages = []
            }
            addUserInput = ""
            addUserSuccess = true
            showAddUser = false
        } else {
            addUserError = "User not found. Please check the email or phone number."
        }
    }
    
    func resetAddUser() {
        addUserInput = ""
        addUserError = nil
        addUserSuccess = false
    }
}
