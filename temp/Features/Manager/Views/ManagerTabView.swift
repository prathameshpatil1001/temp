//
//  ManagerTabView.swift
//  lms_project
//

import SwiftUI

struct ManagerTabView: View {

    
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab = 0
    @State private var showProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ManagerDashboardView(selectedTab: $selectedTab, showProfile: $showProfile)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            ManagerApprovalsView(selectedTab: $selectedTab, showProfile: $showProfile)
                .tabItem {
                    Label("Approvals", systemImage: "checkmark.circle.fill")
                }
                .tag(1)
            
            ManagerDstView(showProfile: $showProfile)
                .tabItem {
                    Label("DST", systemImage: "person.2.badge.gearshape.fill")
                }
                .tag(2)
            
            ManagerMessagesView(showProfile: $showProfile)
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(3)
        }
        .tint(ManagerTheme.Colors.primary(colorScheme))
        .sheet(isPresented: $showProfile) {
            ManagerProfileView()
        }
    }
}
