import SwiftUI

// MARK: - Tab Item Config
struct TabItem {
    let tag: Int
    let title: String
    let icon: String
    let selectedIcon: String
    var badge: Int = 0
}

// MARK: - View Modifier for Tab Badge
struct TabBadgeModifier: ViewModifier {
    let count: Int

    func body(content: Content) -> some View {
        content.badge(count > 0 ? count : 0)
    }
}

extension View {
    func tabBadge(_ count: Int) -> some View {
        modifier(TabBadgeModifier(count: count))
    }
}


