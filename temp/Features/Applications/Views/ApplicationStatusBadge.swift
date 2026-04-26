import SwiftUI

struct ApplicationStatusBadge: View {
    let status: ApplicationStatus
    var showDot: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            if showDot {
                Circle()
                    .fill(status.dotColor)
                    .frame(width: 7, height: 7)
            }
            Text(status.rawValue)
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
