// App/LoanOSApp.swift
// LoanOS — Borrower App
// App entry point and root view coordinator.
//
// ── App flow ─────────────────────────────────────────────────
// FIRST LAUNCH  ─ Login screen with "Sign Up" link
// SIGNUP        ─ details → OTP → passkey guidance → sign in
// LOGIN         ─ email+password → OTP/TOTP → Home
// RETURNING     ─ Quick-login: Face ID  OR  TOTP code  →  Home
// ─────────────────────────────────────────────────────────────

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - App Entry
// ═══════════════════════════════════════════════════════════════

@main
struct LoanOSApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(session)
        }
    }
}
