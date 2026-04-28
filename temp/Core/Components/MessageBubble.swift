//
//  MessageBubble.swift
//  lms_project
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if message.isFromCurrentUser { Spacer(minLength: 100) }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Color.black)
                    }
                    
                    // Attachment
                    if let attachmentName = message.attachmentName {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: attachmentIconName(for: attachmentName))
                                .font(.system(size: 12, weight: .semibold))
                            Text(attachmentName)
                                .font(Theme.Typography.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    // sent = grey, received = white
                    message.isFromCurrentUser
                        ? Color(hex: "#E5E5EA")
                        : Color.white
                )
                .clipShape(ChatBubbleShape(isFromCurrentUser: message.isFromCurrentUser))
                .overlay(
                    ChatBubbleShape(isFromCurrentUser: message.isFromCurrentUser)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                
                Text(message.timestamp.timeFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromCurrentUser { Spacer(minLength: 100) }
        }
    }
    
    private func attachmentIconName(for attachmentName: String) -> String {
        let lowercasedName = attachmentName.lowercased()
        if lowercasedName.hasSuffix(".jpg") || lowercasedName.hasSuffix(".jpeg") || lowercasedName.hasSuffix(".png") || lowercasedName.hasSuffix(".heic") {
            return "photo.fill"
        }
        if lowercasedName.hasSuffix(".pdf") {
            return "doc.richtext.fill"
        }
        return "doc.fill"
    }
}

struct ChatBubbleShape: Shape {
    let isFromCurrentUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [
                .topLeft, .topRight,
                isFromCurrentUser ? .bottomLeft : .bottomRight
            ],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}
