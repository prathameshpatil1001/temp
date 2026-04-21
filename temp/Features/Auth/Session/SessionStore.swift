// Models/SessionStore.swift
// LoanOS — Borrower App
// Manages and persists the user's login session.

import SwiftUI
import Combine

// ═══════════════════════════════════════════════════════════════
// MARK: - Session Store  (UI-facing observable state)
// ═══════════════════════════════════════════════════════════════

@MainActor
final class SessionStore: ObservableObject {

    @Published var isLoggedIn: Bool
    @Published var isAppUnlocked: Bool
    @Published var justLoggedIn: Bool = false
    @Published var kycStatus: KYCStatus = .notStarted
    @Published var userName: String // Still kept locally for display purposes
    @Published var userEmail: String
    @Published var userPhone: String
    @Published var showSessionExpiredAlert: Bool = false
    @Published var pendingKYCRoute: KYCRoute? = nil
    @Published var logoutBannerMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    init() {
        // App starts logged in only if the secure KeyChain tells us there's a stored session
        let hasStoredSession = TokenStore.shared.hasStoredSession()
        isLoggedIn = hasStoredSession
        isAppUnlocked = !hasStoredSession
        userName   = UserDefaults.standard.string(forKey: "loanOS_userName") ?? ""
        userEmail  = UserDefaults.standard.string(forKey: "loanOS_userEmail") ?? ""
        userPhone  = UserDefaults.standard.string(forKey: "loanOS_userPhone") ?? ""
        // Real implementation would read cached KYC status or fetch it globally
        
        NotificationCenter.default.publisher(for: .sessionExpired)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSessionExpired()
            }
            .store(in: &cancellables)
    }

    private func handleSessionExpired() {
        showSessionExpiredAlert = true
        logout()
    }

    /// Registers the session state locally when backend login succeeds.
    func completeSession(
        name: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        contactIdentifier: String? = nil,
        kycStatus: KYCStatus = .notStarted
    ) {
        if let contactIdentifier {
            applyContactIdentifier(contactIdentifier)
            applyStagedSignupProfile(for: contactIdentifier)
        }
        if let name {
            updateName(name)
        }
        if let email {
            updateEmail(email)
        }
        if let phone {
            updatePhone(phone)
        }
        self.kycStatus = kycStatus
        self.logoutBannerMessage = nil
        isLoggedIn = true
        isAppUnlocked = true
        justLoggedIn = true
    }

    func unlockAppSession() {
        guard isLoggedIn else { return }
        isAppUnlocked = true
    }

    func updateName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        userName = trimmedName
        UserDefaults.standard.set(trimmedName, forKey: "loanOS_userName")
    }

    func updateEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
        userEmail = trimmedEmail
        UserDefaults.standard.set(trimmedEmail, forKey: "loanOS_userEmail")
    }

    func updatePhone(_ phone: String) {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else { return }
        userPhone = trimmedPhone
        UserDefaults.standard.set(trimmedPhone, forKey: "loanOS_userPhone")
    }

    static func stageSignupProfile(name: String, email: String, phone: String) {
        let profile: [String: String] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines)
        ]

        [email, phone]
            .map { normalizedProfileIdentifier($0) }
            .filter { !$0.isEmpty }
            .forEach { identifier in
                UserDefaults.standard.set(profile, forKey: stagedSignupProfilePrefix + identifier)
            }
    }

    /// Securely logs out via the SessionManager.
    func logout(reason: String? = nil) {
        logoutBannerMessage = reason
        // Clear UI state FIRST so screens disappear immediately
        self.isLoggedIn = false
        self.isAppUnlocked = false
        self.justLoggedIn = false
        self.kycStatus = .notStarted

        // Then do backend cleanup in background (best effort)
        Task {
            if #available(iOS 18.0, *) {
                await SessionManager.shared.logout()
            }
        }
    }

    /// Verifies a TOTP code during quick login by calling VerifyTOTPSetup on the backend.
    func verifyQuickTOTP(code: String) async throws -> Bool {
        if #available(iOS 18.0, *) {
            let repository = AuthRepository()
            
            do {
                // Attempt with current tokens
                let tokens = try await repository.verifyTOTPSetup(code: code)
                try SessionManager.shared.startSession(tokens: tokens)
                unlockAppSession()
                return true
            } catch let error as AuthError {
                // If unauthenticated/session expired, try one silent refresh
                if case .sessionExpired = error {
                    if await SessionManager.shared.attemptSilentRestore() {
                        let tokens = try await repository.verifyTOTPSetup(code: code)
                        try SessionManager.shared.startSession(tokens: tokens)
                        unlockAppSession()
                        return true
                    }
                }
                throw error
            } catch {
                throw error
            }
        }
        return false
    }

    private func applyContactIdentifier(_ identifier: String) {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else { return }

        let normalizedIdentifier = Self.normalizedProfileIdentifier(trimmedIdentifier)
        let matchesCurrentEmail = normalizedIdentifier == Self.normalizedProfileIdentifier(userEmail)
        let matchesCurrentPhone = normalizedIdentifier == Self.normalizedProfileIdentifier(userPhone)

        if trimmedIdentifier.contains("@") {
            updateEmail(trimmedIdentifier)
            if !matchesCurrentEmail {
                clearName()
                clearPhone()
            }
        } else {
            updatePhone(trimmedIdentifier)
            if !matchesCurrentPhone {
                clearName()
                clearEmail()
            }
        }
    }

    private func applyStagedSignupProfile(for identifier: String) {
        let key = Self.stagedSignupProfilePrefix + Self.normalizedProfileIdentifier(identifier)
        guard let profile = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else { return }

        updateName(profile["name"] ?? "")
        updateEmail(profile["email"] ?? "")
        updatePhone(profile["phone"] ?? "")
        UserDefaults.standard.removeObject(forKey: key)

        for relatedIdentifier in [profile["email"], profile["phone"]].compactMap({ $0 }) {
            let relatedKey = Self.stagedSignupProfilePrefix + Self.normalizedProfileIdentifier(relatedIdentifier)
            UserDefaults.standard.removeObject(forKey: relatedKey)
        }
    }

    private static let stagedSignupProfilePrefix = "loanOS_staged_signup_profile_"

    private func clearName() {
        userName = ""
        UserDefaults.standard.removeObject(forKey: "loanOS_userName")
    }

    private func clearEmail() {
        userEmail = ""
        UserDefaults.standard.removeObject(forKey: "loanOS_userEmail")
    }

    private func clearPhone() {
        userPhone = ""
        UserDefaults.standard.removeObject(forKey: "loanOS_userPhone")
    }

    private static func normalizedProfileIdentifier(_ identifier: String) -> String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
