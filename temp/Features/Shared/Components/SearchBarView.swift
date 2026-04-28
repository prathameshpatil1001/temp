import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search by name or phone"
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? Color.brandBlue : Color.textTertiary)
                .font(.system(size: 15, weight: .medium))

            TextField(placeholder, text: $text)
                .font(AppFont.body())
                .foregroundColor(Color.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.textTertiary)
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm + 2)
        .background(Color.surfaceGlass)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(isFocused ? Color.brandBlue.opacity(0.4) : Color.borderLight, lineWidth: isFocused ? 1.5 : 1)
        )
        .cardShadow()
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}
