import SwiftUI

// MARK: - Timeline Section
struct TimelineSectionView: View {
    let events: [TimelineEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {

            Text("TIMELINE")
                .font(AppFont.captionMed())
                .foregroundColor(Color.textTertiary)
                .tracking(0.6)
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {

                        // Dot + vertical connector
                        VStack(spacing: 0) {
                            Circle()
                                .fill(event.isRejected ? Color.statusRejected : Color.brandBlue)
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)

                            if idx < events.count - 1 {
                                Rectangle()
                                    .fill(Color.borderLight)
                                    .frame(width: 1.5)
                                    .frame(maxHeight: .infinity)
                                    .padding(.bottom, 2)
                            }
                        }
                        .frame(width: 10)

                        // Content
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(AppFont.bodyMedium())
                                .foregroundColor(Color.textPrimary)
                            Text(event.description)
                                .font(AppFont.subhead())
                                .foregroundColor(Color.textSecondary)
                            Text(event.time)
                                .font(AppFont.caption())
                                .foregroundColor(Color.textTertiary)
                        }
                        .padding(.bottom, idx < events.count - 1 ? AppSpacing.md : 0)

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, idx == 0 ? AppSpacing.md : 0)
                    .padding(.bottom, idx == events.count - 1 ? AppSpacing.md : 0)
                }
            }
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(Color.borderLight, lineWidth: 1)
            )
        }
    }
}

// MARK: - Recent Messages Section
struct RecentMessagesSectionView: View {
    let messages: [LeadMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {

            Text("RECENT MESSAGES")
                .font(AppFont.captionMed())
                .foregroundColor(Color.textTertiary)
                .tracking(0.6)
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: 0) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { idx, msg in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {

                        // Sender dot
                        Circle()
                            .fill(msg.isMe ? Color.brandBlue : Color.textTertiary)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: AppSpacing.xs) {
                                Text(msg.sender)
                                    .font(AppFont.captionMed())
                                    .foregroundColor(Color.textTertiary)
                                Text(msg.time)
                                    .font(AppFont.caption())
                                    .foregroundColor(Color.textTertiary)
                            }
                            Text(msg.text)
                                .font(AppFont.body())
                                .foregroundColor(Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, idx == 0 ? AppSpacing.md : AppSpacing.sm)
                    .padding(.bottom, idx == messages.count - 1 ? AppSpacing.md : 0)

                    if idx < messages.count - 1 {
                        Divider().padding(.leading, AppSpacing.xl + 4)
                    }
                }
            }
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(Color.borderLight, lineWidth: 1)
            )
        }
    }
}
