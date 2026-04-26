import SwiftUI

// MARK: - Messages Tab
struct MessagesPlaceholderView: View {
    var body: some View {
        NavigationStack {
            TabPlaceholderView(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Messages",
                subtitle: "Communicate with your borrowers, RMs, and credit team in one place.",
                color: Color(hex: "#0891B2"),
                badge: 3
            )
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Profile Tab
struct ProfilePlaceholderView: View {
    var body: some View {
        NavigationStack {
            TabPlaceholderView(
                icon: "person.crop.circle.fill",
                title: "Profile",
                subtitle: "Manage your DSA profile, certifications, bank assignments, and account settings.",
                color: Color(hex: "#DB2777")
            )
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Shared Placeholder Component
private struct TabPlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var badge: Int? = nil

    var body: some View {
        ZStack {
            Color.surfaceSecondary.ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .fill(color.opacity(0.1))
                            .frame(width: 80, height: 80)
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(color)
                    }
                    if let badge {
                        Text("\(badge)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.statusRejected)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }

                VStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppFont.title2())
                        .foregroundColor(Color.textPrimary)

                    Text(subtitle)
                        .font(AppFont.subhead())
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xxl)

                    Text("Coming in next sprint")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textTertiary)
                        .padding(.top, AppSpacing.xxs)
                }

                Spacer()
            }
        }
    }
}
