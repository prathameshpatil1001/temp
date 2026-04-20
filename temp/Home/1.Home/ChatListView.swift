import SwiftUI

struct ChatPreviewModel: Identifiable {
    let id = UUID()
    let agentName: String
    let topic: String
    let lastMessage: String
    let time: String
    let hasUnread: Bool
    let isClosed: Bool
}

struct ChatListView: View {
    @EnvironmentObject var router: Router
    
    let chats: [ChatPreviewModel] = [
            ChatPreviewModel(agentName: "Rajesh K.", topic: String(localized: "Document Verification"), lastMessage: String(localized: "Yes, the PAN card upload is confirmed. We will..."), time: "10:42 AM", hasUnread: true, isClosed: false),
            ChatPreviewModel(agentName: "Support Bot", topic: String(localized: "General Inquiry"), lastMessage: String(localized: "Your EMI has been successfully received."), time: String(localized: "Yesterday"), hasUnread: false, isClosed: false),
            ChatPreviewModel(agentName: "Priya S.", topic: String(localized: "Prepayment Query"), lastMessage: String(localized: "You can close this ticket if you have no further questions."), time: "12 Apr", hasUnread: false, isClosed: true)
    ]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
                    
                    // Search Bar Placeholder
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        Text("Search conversations...").foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    
                    // Chat List
                    LazyVStack(spacing: 16) {
                        ForEach(chats) { chat in
                            Button {
                                router.push(.chatConversation(agentName: chat.agentName))
                            } label: {
                                ChatPreviewRow(chat: chat)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 80) // Space for floating button
                }
            }
            
            // Floating New Chat Button
            Button {
                router.push(.chatConversation(agentName: "Support Agent"))
            } label: {
                Image(systemName: "plus.message.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(18)
                    .background(Color.mainBlue)
                    .clipShape(Circle())
                    .shadow(color: .mainBlue.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(20)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ChatPreviewRow: View {
    let chat: ChatPreviewModel
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            
            // Avatar
            ZStack {
                Circle()
                    .fill(chat.isClosed ? Color.secondary.opacity(0.2) : Color.lightBlue)
                    .frame(width: 50, height: 50)
                
                Text(String(chat.agentName.prefix(1)))
                    .font(.title3).bold()
                    .foregroundColor(chat.isClosed ? .secondary : .mainBlue)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.agentName)
                        .font(.headline)
                        .foregroundColor(chat.isClosed ? .secondary : .primary)
                    Spacer()
                    Text(chat.time)
                        .font(.caption)
                        .foregroundColor(chat.hasUnread ? .mainBlue : .secondary)
                }
                
                Text(chat.topic)
                    .font(.caption).bold()
                    .foregroundColor(.secondary)
                
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Unread Badge
            if chat.hasUnread {
                Circle()
                    .fill(Color.mainBlue)
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView().environmentObject(Router())
    }
}
