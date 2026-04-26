import SwiftUI

struct LeadRowView: View {
    let lead: Lead
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: AppSpacing.sm) {

                // Avatar
                AvatarView(
                    initials: lead.initials,
                    color: lead.name.avatarColor,
                    size: 48
                )

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(lead.name)
                            .font(AppFont.bodyMedium())
                            .foregroundColor(Color.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        StatusBadgeView(status: lead.status)
                    }

                    HStack(spacing: 6) {
                        // Loan type icon + label
                        Image(systemName: lead.loanType.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.textTertiary)

                        Text(lead.loanType.rawValue)
                            .font(AppFont.subhead())
                            .foregroundColor(Color.textSecondary)

                        Text("·")
                            .foregroundColor(Color.textTertiary)
                            .font(AppFont.subhead())

                        Text(lead.formattedAmount)
                            .font(AppFont.subheadMed())
                            .foregroundColor(Color.textSecondary)

                        Spacer()

                        Text(lead.timeAgo)
                            .font(AppFont.caption())
                            .foregroundColor(Color.textTertiary)
                    }
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.surfacePrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swipe Actions Row Wrapper
struct SwipeableLeadRow: View {
    let lead: Lead
    var onEdit: (() -> Void)?   = nil
    var onDelete: (() -> Void)? = nil
    var onCall: (() -> Void)?   = nil
    var onTap: (() -> Void)?    = nil

    var body: some View {
        LeadRowView(lead: lead, onTap: onTap)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    onEdit?()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Color.brandBlue)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    onCall?()
                } label: {
                    Label("Call", systemImage: "phone.fill")
                }
                .tint(Color.statusSubmitted)
            }
    }
}
