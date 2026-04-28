//
//  AdminTabView.swift
//  lms_project
//
//  REDESIGNED: 5-tab architecture
//  Dashboard | Loans | Risk & Collections | Reports | System Control
//

import SwiftUI

struct AdminTabView: View {

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var adminVM: AdminViewModel
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var messagesVM: MessagesViewModel

    @StateObject private var loansVM       = AdminLoansViewModel()
    @StateObject private var riskVM        = AdminRiskViewModel()
    @StateObject private var collectionsVM = AdminCollectionsViewModel()
    @StateObject private var reportsVM     = AdminReportsViewModel()

    @State private var selectedTab = 0
    @State private var showProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── TAB 0 ── Dashboard
            AdminDashboardView(showProfile: $showProfile, selectedTab: $selectedTab)
                .environmentObject(adminVM)
                .environmentObject(dashboardVM)
                .environmentObject(authVM)
                .environmentObject(loansVM)
                .environmentObject(riskVM)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
                .tag(0)

            // ── TAB 1 ── Loans
            AdminLoansView(showProfile: $showProfile)
                .environmentObject(loansVM)
                .tabItem {
                    Label("Loans", systemImage: "doc.text")
                }
                .tag(1)

            // ── TAB 2 ── Risk & Collections
            AdminRiskView(showProfile: $showProfile, selectedTab: $selectedTab)
                .environmentObject(adminVM)
                .environmentObject(riskVM)
                .environmentObject(collectionsVM)
                .tabItem {
                    Label("Risk", systemImage: "exclamationmark.shield")
                }
                .tag(2)

            // ── TAB 3 ── Reports
            AdminReportsView(showProfile: $showProfile)
                .environmentObject(reportsVM)
                .tabItem {
                    Label("Reports", systemImage: "doc.text")
                }
                .tag(3)

            // ── TAB 4 ── System Control
            AdminSystemControlView(showProfile: $showProfile)
                .environmentObject(adminVM)
                .environmentObject(messagesVM)
                .tabItem {
                    Label("System", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(Theme.Colors.adaptivePrimary(colorScheme))
        .sheet(isPresented: $showProfile) {
            LOProfileView(isModal: true)
                .environmentObject(authVM)
        }
    }
}
