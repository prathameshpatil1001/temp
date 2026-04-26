import SwiftUI

struct FilterChipView: View {
    let filter: LeadFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(filter.title)
                    .font(AppFont.subheadMed())

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : Color.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.surfaceTertiary)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.brandBlue)
                    } else {
                        Capsule().fill(Color.surfacePrimary)
                    }
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.borderLight,
                        lineWidth: 1
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
