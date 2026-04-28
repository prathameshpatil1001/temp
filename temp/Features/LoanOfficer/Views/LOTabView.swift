//
//  LOTabView.swift
//  lms_project
//

import SwiftUI
import UIKit

struct LOTabView: View {

    @State private var selectedTab = 0
    @State private var showProfile = false

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LODashboardView(selectedTab: $selectedTab, showProfile: $showProfile)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            LOApplicationsView(showProfile: $showProfile)
                .tabItem {
                    Label("Applications", systemImage: "doc.text.fill")
                }
                .tag(1)

            LOMessagesView(showProfile: $showProfile)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(2)
        }
        .tint(Theme.Colors.primary)
        .sheet(isPresented: $showProfile) {
            LOProfileView(isModal: true)
        }
    }

    // MARK: - Tab Bar Appearance

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        // Larger icon configuration (28 pt)
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray3

        // Label font – larger than default
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.systemGray3
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold)
        ]

        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs

        // Vertical padding so icons & labels breathe
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 2)
        appearance.stackedItemPositioning = .automatic
        appearance.stackedItemWidth = 60

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
