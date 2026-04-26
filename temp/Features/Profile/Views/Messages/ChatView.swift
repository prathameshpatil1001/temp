// MARK: - ChatView.swift

import SwiftUI
import PhotosUI

struct ChatView: View {

    @StateObject var vm: ChatViewModel
    @FocusState private var inputFocused: Bool
    @State private var selectedAttachment: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(vm.groupedMessages, id: \.date) { group in
                            DateSeparator(label: group.date)

                            ForEach(group.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .background(Color.surfaceSecondary)
                .onAppear {
                    scrollToBottom(proxy: proxy, animated: false)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: inputFocused) { _, focused in
                    if focused { scrollToBottom(proxy: proxy) }
                }
            }

            composerBar
        }
        .background(Color.surfaceSecondary)
        .navigationTitle(vm.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(vm.navigationTitle)
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                    Text(vm.navigationSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.brandBlue)
                }
            }
        }
    }

    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = vm.linkedLeadSummary {
                HStack(spacing: 6) {
                    Image(systemName: "link.circle.fill")
                        .font(AppFont.captionMed())
                        .foregroundColor(Color.brandBlue)
                    Text("Connected")
                        .font(AppFont.captionMed())
                        .foregroundColor(Color.brandBlue)
                    Text(summary)
                        .font(AppFont.caption())
                        .foregroundColor(Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Text("Direct Sales Team and loan officer are now connected in this thread.")
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .background(Color.surfacePrimary)
        .overlay(
            Rectangle()
                .fill(Color.borderLight)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(
                selection: $selectedAttachment,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Color.surfaceTertiary, in: Circle())
            }
            .onChange(of: selectedAttachment) { newItem in
                guard newItem != nil else { return }
                vm.sendAttachment(fileName: "Document Attachment")
                selectedAttachment = nil
            }

            TextField("Message...", text: $vm.draftText, axis: .vertical)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.surfaceTertiary)
                )
                .focused($inputFocused)
                .lineLimit(1...5)
                .foregroundStyle(Color.textPrimary)

            Button(action: vm.sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        vm.canSend ? Color.brandBlue : Color.borderMedium,
                        in: Circle()
                    )
            }
            .disabled(!vm.canSend)
            .animation(.easeInOut(duration: 0.15), value: vm.canSend)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.surfacePrimary)
        .overlay(
            Rectangle()
                .fill(Color.borderLight)
                .frame(height: 1),
            alignment: .top
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    private let maxBubbleWidth: CGFloat = 290

    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
                bubble
            } else {
                bubble
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    private var bubble: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 6) {
            if message.attachmentRef != nil {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(message.isFromMe ? Color.brandBlue : Color.textSecondary)
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)
                }
            } else {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(message.isFromMe ? .white : Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 4) {
                Spacer(minLength: 0)
                Text(message.timeString)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(message.isFromMe ? .white.opacity(0.75) : Color.textTertiary)

                if message.isFromMe {
                    Image(systemName: "checkmark.double")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(message.isFromMe ? .white.opacity(0.75) : Color.brandBlue)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: maxBubbleWidth, alignment: message.isFromMe ? .trailing : .leading)
        .background(bubbleBackground)
        .clipShape(bubbleShape)
    }

    private var bubbleBackground: Color {
        if message.isFromMe {
            return Color.brandBlue
        } else if message.senderRole == .system {
            return Color.surfaceTertiary
        } else {
            return Color.surfacePrimary
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: message.isFromMe ? 18 : 6,
            bottomTrailingRadius: message.isFromMe ? 6 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }
}

struct DateSeparator: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.borderLight, in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
}

// Removed dark ChatBackdrop — using Color.surfaceSecondary directly
