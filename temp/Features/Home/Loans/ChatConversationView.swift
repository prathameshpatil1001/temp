import SwiftUI
import Combine

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isCurrentUser: Bool
    let time: String
}

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "Hi there! I noticed my PAN card was rejected during the upload. What went wrong?", isCurrentUser: true, time: "10:30 AM"),
        ChatMessage(text: "Hello! Let me check that for you.", isCurrentUser: false, time: "10:32 AM"),
        ChatMessage(text: "It looks like the image was a bit blurry and the system couldn't read the ID number. Could you please re-upload a clearer picture?", isCurrentUser: false, time: "10:33 AM"),
        ChatMessage(text: "Sure, let me do that right now.", isCurrentUser: true, time: "10:35 AM"),
        ChatMessage(text: "Yes, the new PAN card upload is confirmed. We will proceed with the verification.", isCurrentUser: false, time: "10:42 AM")
    ]
    @Published var inputText: String = ""

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let newMsg = ChatMessage(text: inputText, isCurrentUser: true, time: "Just now")
        messages.append(newMsg)
        inputText = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let reply = ChatMessage(
                text: "Thanks! I've received your message. Is there anything else I can help with?",
                isCurrentUser: false,
                time: "Just now"
            )
            self.messages.append(reply)
        }
    }
}

struct ChatConversationView: View {
    let agentName: String

    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ChatScrollOffsetReader()
                                .frame(height: 0)
                            LazyVStack(spacing: 2) {
                                ForEach(viewModel.messages) { message in
                                    ChatBubble(message: message, agentName: agentName)
                                        .id(message.id)
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
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.22)) {
                                scrollProxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                MessagesNavigationBar(
                    agentName: agentName,
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
    }
}

struct MessagesNavigationBar: View {
    let agentName: String
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
                            Text(String(agentName.prefix(1)))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.mainBlue)
                        )
                        .scaleEffect(0.84 + (0.16 * collapseProgress))

                    VStack(spacing: 1) {
                        Text(agentName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("Support Agent")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .opacity(0.18 + (0.82 * collapseProgress))
                }
                .frame(maxWidth: .infinity)

                Spacer()

                HStack(spacing: 18) {
                    Button {} label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.mainBlue)
                    }

                    Button {} label: {
                        Image(systemName: "video.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.mainBlue)
                    }
                }
                .frame(width: 72, alignment: .trailing)
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
    let agentName: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 6) {
                if message.isCurrentUser {
                    Spacer(minLength: 60)
                } else {
                    Circle()
                        .fill(DS.primaryLight)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(agentName.prefix(1)))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.mainBlue)
                        )
                }

                Text(message.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1.5)
                    .foregroundColor(message.isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 255, alignment: message.isCurrentUser ? .trailing : .leading)
                    .background(
                        message.isCurrentUser
                            ? DS.primary
                            : Color(UIColor.secondarySystemGroupedBackground)
                    )
                    .clipShape(BubbleShape(isCurrentUser: message.isCurrentUser))

                if !message.isCurrentUser {
                    Spacer(minLength: 60)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)

            HStack {
                if message.isCurrentUser {
                    Spacer()
                }

                Text(message.time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, message.isCurrentUser ? 18 : 50)

                if !message.isCurrentUser {
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
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                Button {} label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.mainBlue)
                }

                HStack {
                    TextField("iMessage", text: $viewModel.inputText)
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
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.clear)
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
