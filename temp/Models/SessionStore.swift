// Models/SessionStore.swift
// LoanOS — Direct Sales Team App
// Manages and persists the user's login session.

import SwiftUI
import Combine

@MainActor
final class SessionStore: ObservableObject {

    @Published var isLoggedIn: Bool
    @Published var isAppUnlocked: Bool
    @Published var justLoggedIn: Bool = false
    @Published var userName: String
    @Published var userEmail: String
    @Published var userPhone: String
    @Published var showSessionExpiredAlert: Bool = false
    @Published var logoutBannerMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    init() {
        let hasStoredSession = TokenStore.shared.hasStoredSession()
        isLoggedIn = hasStoredSession
        isAppUnlocked = !hasStoredSession
        userName   = UserDefaults.standard.string(forKey: "dst_userName") ?? ""
        userEmail  = UserDefaults.standard.string(forKey: "dst_userEmail") ?? ""
        userPhone  = UserDefaults.standard.string(forKey: "dst_userPhone") ?? ""

        NotificationCenter.default.publisher(for: .sessionExpired)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSessionExpired()
            }
            .store(in: &cancellables)
    }

    private func handleSessionExpired() {
        guard isLoggedIn else { return }
        showSessionExpiredAlert = true
        logout()
    }

    func completeSession(
        name: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        contactIdentifier: String? = nil
    ) {
        if let contactIdentifier {
            applyContactIdentifier(contactIdentifier)
            applyStagedProfile(for: contactIdentifier)
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
        self.logoutBannerMessage = nil
        isLoggedIn = true
        isAppUnlocked = true
        justLoggedIn = true
    }

    func completeSessionFromBackend(contactIdentifier: String? = nil) async {
        if #available(iOS 18.0, *) {
            do {
                let profile = try await AuthRepository().getMyProfile()
                completeSession(
                    name: profile.fullName,
                    email: profile.email,
                    phone: profile.phone,
                    contactIdentifier: contactIdentifier
                )
                return
            } catch {
                // Fallback: preserve previous behavior when profile fetch fails.
            }
        }
        completeSession(contactIdentifier: contactIdentifier)
    }

    func unlockAppSession() {
        guard isLoggedIn else { return }
        isAppUnlocked = true
    }

    func updateName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        userName = trimmedName
        UserDefaults.standard.set(trimmedName, forKey: "dst_userName")
    }

    func updateEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
        userEmail = trimmedEmail
        UserDefaults.standard.set(trimmedEmail, forKey: "dst_userEmail")
    }

    func updatePhone(_ phone: String) {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else { return }
        userPhone = trimmedPhone
        UserDefaults.standard.set(trimmedPhone, forKey: "dst_userPhone")
    }

    static func stageProfile(name: String, email: String, phone: String) {
        let profile: [String: String] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines)
        ]

        [email, phone]
            .map { normalizedProfileIdentifier($0) }
            .filter { !$0.isEmpty }
            .forEach { identifier in
                UserDefaults.standard.set(profile, forKey: stagedProfilePrefix + identifier)
            }
    }

    func logout(reason: String? = nil) {
        logoutBannerMessage = reason
        // Clear UI state synchronously FIRST so screens disappear immediately
        self.isLoggedIn = false
        self.isAppUnlocked = false
        self.justLoggedIn = false

        // Then do backend cleanup in background (best effort)
        Task {
            if #available(iOS 18.0, *) {
                await SessionManager.shared.logout()
            }
        }
    }

    // MARK: - Quick Login (Reopen + MFA)

    /// Quick login using TOTP via the backend's InitiateReopen + MFA flow.
    func verifyQuickReopenMFA(
        factor: String,
        code: String
    ) async throws -> Bool {
        guard #available(iOS 18.0, *) else { return false }

        let repository = AuthRepository()
        let reopen = try await repository.initiateReopen()

        guard reopen.allowedFactors.contains(factor) else {
            throw AuthError.invalidServerResponse("Factor \(factor) is not available for this account.")
        }

        _ = try await repository.selectLoginFactor(
            mfaSessionID: reopen.mfaSessionID,
            factor: factor
        )

        let factorSelection: Auth_V1_VerifyLoginMFARequest.OneOf_Factor
        switch factor {
        case "totp":
            factorSelection = .totpCode(code)
        default:
            throw AuthError.invalidServerResponse("Unsupported quick login method.")
        }

        let tokens = try await repository.verifyLoginMFA(
            mfaSessionID: reopen.mfaSessionID,
            factorSelection: factorSelection
        )
        try SessionManager.shared.startSession(tokens: tokens)
        await completeSessionFromBackend()
        return true
    }

    /// First step of OTP-based quick login: InitiateReopen + select factor to send OTP.
    func beginQuickReopenOTP(factor: String) async throws -> (mfaSessionID: String, challengeTarget: String) {
        guard #available(iOS 18.0, *) else { throw AuthError.unknown }
        guard factor == "email_otp" || factor == "phone_otp" else {
            throw AuthError.invalidServerResponse("Unsupported quick login method.")
        }

        let repository = AuthRepository()
        let reopen = try await repository.initiateReopen()

        guard reopen.allowedFactors.contains(factor) else {
            throw AuthError.invalidServerResponse("Factor \(factor) is not available for this account.")
        }

        let selection = try await repository.selectLoginFactor(
            mfaSessionID: reopen.mfaSessionID,
            factor: factor
        )
        return (mfaSessionID: reopen.mfaSessionID, challengeTarget: selection.challengeTarget)
    }

    /// Second step of OTP-based quick login: verify the OTP code.
    func verifyQuickReopenOTP(mfaSessionID: String, factor: String, code: String) async throws -> Bool {
        guard #available(iOS 18.0, *) else { return false }
        guard factor == "email_otp" || factor == "phone_otp" else {
            throw AuthError.invalidServerResponse("Unsupported quick login method.")
        }

        let repository = AuthRepository()
        let factorSelection: Auth_V1_VerifyLoginMFARequest.OneOf_Factor =
            factor == "email_otp" ? .emailOtpCode(code) : .phoneOtpCode(code)

        let tokens = try await repository.verifyLoginMFA(
            mfaSessionID: mfaSessionID,
            factorSelection: factorSelection
        )
        try SessionManager.shared.startSession(tokens: tokens)
        await completeSessionFromBackend()
        return true
    }

    /// Quick login using passkey via InitiateReopen + WebAuthn.
    func verifyQuickReopenPasskey() async throws -> Bool {
        guard #available(iOS 18.0, *) else { return false }

        let repository = AuthRepository()
        let reopen = try await repository.initiateReopen()

        guard reopen.allowedFactors.contains("webauthn") else {
            throw AuthError.invalidServerResponse("Passkey is not available for this account.")
        }

        guard let accessToken = try TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            throw AuthError.unauthenticated
        }

        _ = try await repository.selectLoginFactor(
            mfaSessionID: reopen.mfaSessionID,
            factor: "webauthn"
        )

        let loginCtx = try await repository.beginPasskeyLogin(userID: userID)
        let assertion = try await PasskeyManager.shared.getAssertion(from: loginCtx.requestOptionsJSON)

        let tokens = try await repository.finishPasskeyLogin(
            mfaSessionID: loginCtx.mfaSessionID,
            assertionJSON: assertion
        )
        try SessionManager.shared.startSession(tokens: tokens)
        await completeSessionFromBackend()
        return true
    }

    // MARK: - Private Helpers

    private func applyContactIdentifier(_ identifier: String) {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else { return }

        let normalizedIdentifier = Self.normalizedProfileIdentifier(trimmedIdentifier)
        let matchesCurrentEmail = normalizedIdentifier == Self.normalizedProfileIdentifier(userEmail)
        let matchesCurrentPhone = normalizedIdentifier == Self.normalizedProfileIdentifier(userPhone)

        if trimmedIdentifier.contains("@") {
            if !matchesCurrentEmail && !userEmail.isEmpty {
                clearName()
                clearPhone()
            }
            updateEmail(trimmedIdentifier)
        } else {
            if !matchesCurrentPhone && !userPhone.isEmpty {
                clearName()
                clearEmail()
            }
            updatePhone(trimmedIdentifier)
        }
    }

    @discardableResult
    private func applyStagedProfile(for identifier: String) -> Bool {
        let key = Self.stagedProfilePrefix + Self.normalizedProfileIdentifier(identifier)
        guard let profile = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else { return false }

        updateName(profile["name"] ?? "")
        updateEmail(profile["email"] ?? "")
        updatePhone(profile["phone"] ?? "")
        UserDefaults.standard.removeObject(forKey: key)

        for relatedIdentifier in [profile["email"], profile["phone"]].compactMap({ $0 }) {
            let relatedKey = Self.stagedProfilePrefix + Self.normalizedProfileIdentifier(relatedIdentifier)
            UserDefaults.standard.removeObject(forKey: relatedKey)
        }

        return true
    }

    private static let stagedProfilePrefix = "dst_staged_profile_"

    private func clearName() {
        userName = ""
        UserDefaults.standard.removeObject(forKey: "dst_userName")
    }

    private func clearEmail() {
        userEmail = ""
        UserDefaults.standard.removeObject(forKey: "dst_userEmail")
    }

    private func clearPhone() {
        userPhone = ""
        UserDefaults.standard.removeObject(forKey: "dst_userPhone")
    }

    private static func normalizedProfileIdentifier(_ identifier: String) -> String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}