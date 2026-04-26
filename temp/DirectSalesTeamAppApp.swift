import SwiftUI

@main
struct DirectSalesTeamAppApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isLoggedIn {
                    if session.isAppUnlocked {
                        ContentView()
                    } else {
                        QuickLoginGate()
                    }
                } else {
                    LoginRoot()
                }
            }
            .environmentObject(session)
            .alert("Session Expired", isPresented: $session.showSessionExpiredAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your session has expired. Please log in again.")
            }
        }
    }
}
