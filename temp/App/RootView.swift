// App/RootView.swift
// LoanOS Borrower App
// Root coordinator for authenticated and unauthenticated app flows.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Root View
// ═══════════════════════════════════════════════════════════════

/// Top-level coordinator: routes between QuickLoginGate (returning user)
/// and WelcomeFlowController (new / logged-out user).
struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        Group {
            if session.isLoggedIn {
                if session.isAppUnlocked {
                    HomeView()
                } else {
                    QuickLoginGate()
                }
            } else {
                WelcomeFlowController()
            }
        }
        .alert("Session Expired", isPresented: $session.showSessionExpiredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your session has expired. Please log in again.")
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "loanos" else { return }
        if url.host == "kyc" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            switch path {
            case "verifying":
                session.pendingKYCRoute = .verifying
            case "verificationFailed":
                session.pendingKYCRoute = .verificationFailed
            case "verificationSuccess":
                session.pendingKYCRoute = .verificationSuccess
            case "verifyIdentity":
                session.pendingKYCRoute = .verifyIdentity
            default:
                break
            }
        }
    }
}



// ═══════════════════════════════════════════════════════════════
// MARK: - Previews
// ═══════════════════════════════════════════════════════════════

#Preview("First launch") {
    let s = SessionStore(); s.logout()
    return RootView().environmentObject(s)
}

#Preview("Returning user") {
    let s = SessionStore(); s.completeSession(name: "Ravi")
    return RootView().environmentObject(s)
}
