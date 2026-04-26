import SwiftUI

struct StatusBadgeView: View {
    let status: LeadStatus
    var showDot: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            if showDot {
                Circle()
                    .fill(status.dotColor)
                    .frame(width: 7, height: 7)
            }
            Text(status.displayName)
                .font(AppFont.captionMed())
                .foregroundColor(status.textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(status.textColor.opacity(0.18), lineWidth: 1)
        )
    }
}

#Preview {
    HStack {
        StatusBadgeView(status: .new)
        StatusBadgeView(status: .docsPending)
        StatusBadgeView(status: .submitted)
        StatusBadgeView(status: .rejected)
    }
    .padding()
}
