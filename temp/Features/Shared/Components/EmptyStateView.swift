import SwiftUI

struct EmptyStateView: View {
    let filter: LeadFilter
    let searchText: String
    var onAddLead: (() -> Void)? = nil

    var isSearching: Bool { !searchText.isEmpty }

    var icon: String {
        isSearching ? "magnifyingglass" : "person.badge.plus"
    }

    var title: String {
        if isSearching { return "No results for \"\(searchText)\"" }
        if filter.status != nil { return "No \(filter.title) leads" }
        return "No leads yet"
    }

    var subtitle: String {
        if isSearching { return "Try a different name or phone number" }
        if filter.status != nil { return "Leads with '\(filter.title)' status will appear here" }
        return "Tap '+ Add Lead' to start adding your first lead"
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.surfaceTertiary)
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color.textTertiary)
            }

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppFont.headline())
                    .foregroundColor(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }

            if !isSearching && filter.status == nil, let onAddLead {
                Button(action: onAddLead) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "plus")
                        Text("Add Your First Lead")
                    }
                    .font(AppFont.bodyMedium())
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.brandBlue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
