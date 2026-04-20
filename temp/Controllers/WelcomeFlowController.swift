// Controllers/WelcomeFlowController.swift
// LoanOS — Borrower App
// Manages navigation for unauthenticated users.

import SwiftUI

enum WelcomeRoute {
    case welcome
    case login
    case signup
}

/// Owns the routing between the Welcome view, Login flow, and Signup flow.
@MainActor
struct WelcomeFlowController: View {
    @EnvironmentObject private var session: SessionStore
    @State private var route: WelcomeRoute = .welcome

    var body: some View {
        Group {
            switch route {
            case .welcome:
                WelcomeView(
                    bannerMessage: session.logoutBannerMessage,
                    onDismissBanner: { session.logoutBannerMessage = nil },
                    onGoToLogin: { route = .login },
                    onGoToSignup: { route = .signup }
                )
                .transition(.opacity)
            case .login:
                LoginRoot(onGoToSignup: { route = .signup }, onBackToWelcome: { route = .welcome })
                    .transition(.move(edge: .trailing))
            case .signup:
                SignupRoot(onBackToLogin: { route = .login }, onBackToWelcome: { route = .welcome })
                    .transition(.move(edge: .trailing))
            }
        }
        // Use a simple animation to transition between flows
        .animation(.easeInOut(duration: 0.3), value: route)
    }
}

#Preview {
    WelcomeFlowController()
        .environmentObject(SessionStore())
}
