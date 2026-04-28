import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .leads

    enum Tab: Int, CaseIterable {
        case leads        = 0
        case applications = 1
        case messages     = 2
        case earnings     = 3
        case profile      = 4
    }

    // Shared state injected here and passed down as needed
    @StateObject private var leadsViewModel        = LeadsViewModel()
    @StateObject private var applicationsViewModel = ApplicationsViewModel()
    @StateObject private var messagesViewModel     = MessagesViewModel()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.surfacePrimary)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.brandBlue)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.brandBlue)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.textTertiary)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Tab 1: Leads ──
            LeadsView()
                .tabItem {
                    Label("Leads", systemImage: selectedTab == .leads
                          ? "person.2.fill"
                          : "person.2")
                }
                .tag(Tab.leads)

            // ── Tab 2: Applications ──
            ApplicationsView()
                .tabItem {
                    Label("Applications", systemImage: selectedTab == .applications
                          ? "doc.text.fill"
                          : "doc.text")
                }
                .tag(Tab.applications)

            // ── Tab 3: Messages ──
            MessagesView(vm: messagesViewModel)
                .tabItem {
                    Label("Messages", systemImage: selectedTab == .messages
                          ? "message.fill"
                          : "message")
                }
                .tabBadge(messagesViewModel.totalUnread)
                .tag(Tab.messages)

            // ── Tab 4: Earnings ──
            EarningsView()
                .tabItem {
                    Label("Earnings", systemImage: selectedTab == .earnings
                          ? "chart.line.uptrend.xyaxis"
                          : "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.earnings)

            // ── Tab 5: Profile ──
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == .profile
                          ? "person.fill"
                          : "person")
                }
                .tag(Tab.profile)
        }
        .tint(Color.brandBlue)
    }
}

#Preview {
    ContentView()
}
