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
    @StateObject private var session: SessionStore
    @AppStorage(AppLanguage.storageKey) private var selectedLanguageCode = AppLanguage.defaultLanguage.rawValue

    init() {
        Self.clearKeychainOnFreshInstall()
        _session = StateObject(wrappedValue: SessionStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environment(\.locale, AppLanguage.from(storageValue: selectedLanguageCode).locale)
        }
    }

    private static func clearKeychainOnFreshInstall() {
        let hasLaunchedBeforeKey = "loanOS_hasLaunchedBefore"
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)

        guard !hasLaunchedBefore else { return }

        try? TokenStore.shared.clearAll()
        try? DeviceIDStore.shared.reset()
        QuickLoginPreferencesStore.shared.clearAll()
        UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
    }
}
