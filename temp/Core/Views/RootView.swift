//
//  RootView.swift
//  lms_project
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        Group {
            if let role = authVM.currentRole {
                switch role {
                case .loanOfficer:
                    LOTabView()
                case .manager:
                    ManagerTabView()
                case .admin:
                    AdminTabView()
                case .dst:
                    EmptyView()
                }
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.currentRole)
    }
}
