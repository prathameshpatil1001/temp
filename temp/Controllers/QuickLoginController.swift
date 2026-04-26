// Controllers/QuickLoginController.swift
// LoanOS — Borrower App
// Controller for returning users — presents quick login until the
// app session is unlocked, after which RootView switches to HomeView.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Quick Login Controller
// ═══════════════════════════════════════════════════════════════

/// Entry point for returning (already-authenticated) users.
/// Presents Face ID or TOTP quick-login.
struct QuickLoginGate: View {
    var body: some View {
        NavigationStack {
            QuickLoginView()
        }
        .tint(DS.primary)
    }
}
