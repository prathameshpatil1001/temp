import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search by name or phone"

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.textTertiary)
                .font(.system(size: 15, weight: .medium))

            TextField(placeholder, text: $text)
                .font(AppFont.body())
                .foregroundColor(Color.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

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
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm - 2)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.full)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}
