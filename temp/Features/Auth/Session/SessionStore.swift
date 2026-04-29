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
    @Published var isOnboardingComplete: Bool
    @Published var showSessionExpiredAlert: Bool = false
    @Published var pendingKYCRoute: KYCRoute? = nil
    @Published var logoutBannerMessage: String? = nil
    /// The borrower profile UUID returned by GetMyProfile — used when creating loan applications.
    @Published var borrowerProfileId: String
    @Published var profileImageData: Data?
    @Published var hasTotp: Bool

    private var cancellables = Set<AnyCancellable>()

    init() {
        // App starts logged in only if the secure KeyChain tells us there's a stored session
        let hasStoredSession = TokenStore.shared.hasStoredSession()
        isLoggedIn = hasStoredSession
        isAppUnlocked = !hasStoredSession
        userName   = UserDefaults.standard.string(forKey: "loanOS_userName") ?? ""
        userEmail  = UserDefaults.standard.string(forKey: "loanOS_userEmail") ?? ""
        userPhone  = UserDefaults.standard.string(forKey: "loanOS_userPhone") ?? ""
        borrowerProfileId = UserDefaults.standard.string(forKey: "loanOS_borrowerProfileId") ?? ""
        profileImageData = nil
        hasTotp = UserDefaults.standard.bool(forKey: "loanOS_has_totp")
        isOnboardingComplete = false
        refreshOnboardingCompletionStatus()
        refreshProfileImage()
        // Real implementation would read cached KYC status or fetch it globally
        
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

    /// Registers the session state locally when backend login succeeds.
    func completeSession(
        name: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        contactIdentifier: String? = nil,
        kycStatus: KYCStatus = .notStarted,
        hasTotp: Bool? = nil
    ) {
        var appliedStagedSignupProfile = false
        if let contactIdentifier {
            applyContactIdentifier(contactIdentifier)
            appliedStagedSignupProfile = applyStagedSignupProfile(for: contactIdentifier)
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
        if appliedStagedSignupProfile {
            setOnboardingComplete(false)
        }
        refreshOnboardingCompletionStatus()
        refreshProfileImage()
        self.kycStatus = kycStatus
        if let hasTotp {
            updateHasTotp(hasTotp)
        }
        self.logoutBannerMessage = nil
        isLoggedIn = true
        isAppUnlocked = true
        justLoggedIn = true
    }

    func unlockAppSession() {
        guard isLoggedIn else { return }
        isAppUnlocked = true
    }

    func completeSessionFromBackend(contactIdentifier: String? = nil) async {
        if #available(iOS 18.0, *) {
            do {
                let profile = try await AuthRepository().getMyProfile()
                completeSession(
                    name: profile.fullName,
                    email: profile.email,
                    phone: profile.phone,
                    contactIdentifier: contactIdentifier,
                    hasTotp: profile.hasTotp
                )
                setOnboardingComplete(profile.hasBorrowerProfile)
                // Cache the borrower profile ID for loan application flows
                if let pid = profile.borrowerProfileId, !pid.isEmpty {
                    borrowerProfileId = pid
                    UserDefaults.standard.set(pid, forKey: "loanOS_borrowerProfileId")
                }
                do {
                    let kycSnapshot = try await KYCRepository().getBorrowerKycStatus()
                    if kycSnapshot.isAadhaarVerified && kycSnapshot.isPanVerified {
                        kycStatus = .approved
                    } else if profile.hasBorrowerProfile {
                        kycStatus = .pending
                    } else {
                        kycStatus = .notStarted
                    }
                } catch {
                    // Keep session usable even when KYC status fetch fails.
                    kycStatus = profile.hasBorrowerProfile ? .pending : .notStarted
                }
                return
            } catch {
                // Fallback: preserve previous behavior when profile fetch fails.
            }
        }
        completeSession(contactIdentifier: contactIdentifier)
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

    func setOnboardingComplete(_ complete: Bool) {
        guard let identifier = activeOnboardingIdentifier else {
            isOnboardingComplete = complete
            return
        }

        isOnboardingComplete = complete
        UserDefaults.standard.set(complete, forKey: Self.onboardingCompletionKeyPrefix + identifier)
    }

    func updateProfileImage(_ data: Data?) {
        guard let key = activeProfileImageKey else {
            profileImageData = data
            return
        }

        profileImageData = data
        if let data {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
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
        self.isOnboardingComplete = false
        self.kycStatus = .notStarted
        self.borrowerProfileId = ""
        self.hasTotp = false
        UserDefaults.standard.removeObject(forKey: "loanOS_borrowerProfileId")
        UserDefaults.standard.removeObject(forKey: "loanOS_has_totp")

        // Then do backend cleanup in background (best effort)
        Task {
            if #available(iOS 18.0, *) {
                if let accessToken = try? TokenStore.shared.accessToken(),
                   let userID = JWTClaimsDecoder.subject(from: accessToken) {
                    try? TOTPSecretStore.shared.delete(for: userID)
                }
                await SessionManager.shared.logout()
            }
        }
    }

    func updateHasTotp(_ hasTotp: Bool) {
        self.hasTotp = hasTotp
        UserDefaults.standard.set(hasTotp, forKey: "loanOS_has_totp")
    }

    /// Quick login using backend "reopen + MFA" flow (no direct refresh).
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

        let factorSelection: Auth_V1_VerifyLoginMFARequest.OneOf_Factor
        switch factor {
        case "totp":
            _ = try await repository.selectLoginFactor(
                mfaSessionID: reopen.mfaSessionID,
                factor: factor
            )
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

        let selection = try await repository.selectLoginFactor(mfaSessionID: reopen.mfaSessionID, factor: factor)
        return (mfaSessionID: reopen.mfaSessionID, challengeTarget: selection.challengeTarget)
    }

    func verifyQuickReopenOTP(mfaSessionID: String, factor: String, code: String) async throws -> Bool {
        guard #available(iOS 18.0, *) else { return false }
        guard factor == "email_otp" || factor == "phone_otp" else {
            throw AuthError.invalidServerResponse("Unsupported quick login method.")
        }

        let repository = AuthRepository()
        let factorSelection: Auth_V1_VerifyLoginMFARequest.OneOf_Factor =
            factor == "email_otp" ? .emailOtpCode(code) : .phoneOtpCode(code)

        let tokens = try await repository.verifyLoginMFA(mfaSessionID: mfaSessionID, factorSelection: factorSelection)
        try SessionManager.shared.startSession(tokens: tokens)
        await completeSessionFromBackend()
        return true
    }

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

        isOnboardingComplete = onboardingCompletion(for: normalizedIdentifier)
        refreshProfileImage()
    }

    @discardableResult
    private func applyStagedSignupProfile(for identifier: String) -> Bool {
        let key = Self.stagedSignupProfilePrefix + Self.normalizedProfileIdentifier(identifier)
        guard let profile = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else { return false }

        updateName(profile["name"] ?? "")
        updateEmail(profile["email"] ?? "")
        updatePhone(profile["phone"] ?? "")
        UserDefaults.standard.removeObject(forKey: key)

        for relatedIdentifier in [profile["email"], profile["phone"]].compactMap({ $0 }) {
            let relatedKey = Self.stagedSignupProfilePrefix + Self.normalizedProfileIdentifier(relatedIdentifier)
            UserDefaults.standard.removeObject(forKey: relatedKey)
        }

        return true
    }

    private static let stagedSignupProfilePrefix = "loanOS_staged_signup_profile_"
    private static let onboardingCompletionKeyPrefix = "loanOS_onboarding_complete_"
    private static let profileImageKeyPrefix = "loanOS_profile_image_"

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

    private var activeOnboardingIdentifier: String? {
        if let accessToken = try? TokenStore.shared.accessToken(),
           let userID = JWTClaimsDecoder.subject(from: accessToken),
           !userID.isEmpty {
            return Self.normalizedProfileIdentifier(userID)
        }

        let normalizedEmail = Self.normalizedProfileIdentifier(userEmail)
        if !normalizedEmail.isEmpty {
            return normalizedEmail
        }

        let normalizedPhone = Self.normalizedProfileIdentifier(userPhone)
        if !normalizedPhone.isEmpty {
            return normalizedPhone
        }

        return nil
    }

    private func refreshOnboardingCompletionStatus() {
        guard let identifier = activeOnboardingIdentifier else {
            isOnboardingComplete = false
            return
        }
        isOnboardingComplete = onboardingCompletion(for: identifier)
    }

    private func refreshProfileImage() {
        guard let key = activeProfileImageKey else {
            profileImageData = nil
            return
        }
        profileImageData = UserDefaults.standard.data(forKey: key)
    }

    private var activeProfileImageKey: String? {
        guard let identifier = activeOnboardingIdentifier else { return nil }
        return Self.profileImageKeyPrefix + identifier
    }

    private func onboardingCompletion(for identifier: String) -> Bool {
        if let storedValue = UserDefaults.standard.object(forKey: Self.onboardingCompletionKeyPrefix + identifier) as? Bool {
            return storedValue
        }
        return false
    }
}
