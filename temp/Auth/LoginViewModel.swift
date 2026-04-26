// LoginViewModel.swift
// lms_borrower/Auth
//
// Stateful orchestration for the multi-step login flow.
// This view model persists across the entire NavigationStack route.

import SwiftUI
import Combine

@available(iOS 18.0, *)
@MainActor
public final class LoginViewModel: ObservableObject {

    public enum State {
        case idle
        case loading(String)
        case error(String)
        case mfaRequired(allowedFactors: [String])
        case mfaChallengeReceived(factor: String, target: String?)
        case success
    }

    @Published public var state: State = .idle
    @Published public var errorMessage: String? // For alerts
    @Published public var requiresPasswordChange: Bool = false

    private let authRepository: AuthRepository
    private let sessionManager: SessionManager
    private let passkeyManager: PasskeyManager
    private let quickLoginPreferencesStore: QuickLoginPreferencesStore

    // In-memory flow state
    private var mfaSessionID: String?
    var selectedFactorType: String?
    private var webauthnRequestOptions: Data?
    private var pendingIdentifier: String?
    private var pendingPrimaryPassword: String?

    @MainActor
    init(
        authRepository: AuthRepository? = nil,
        sessionManager: SessionManager = .shared,
        passkeyManager: PasskeyManager = .shared,
        quickLoginPreferencesStore: QuickLoginPreferencesStore = .shared
    ) {
        self.authRepository = authRepository ?? AuthRepository()
        self.sessionManager = sessionManager
        self.passkeyManager = passkeyManager
        self.quickLoginPreferencesStore = quickLoginPreferencesStore
    }

    /// Step 1: Submit identifier and password. Returns `true` if MFA is required (will push next screen).
    public func loginPrimary(identifier: String, password: String) async -> Bool {
        state = .loading("Signing in...")
        do {
            let result = try await authRepository.loginPrimary(identifier: identifier, password: password)
            self.pendingIdentifier = identifier
            self.pendingPrimaryPassword = password
            self.requiresPasswordChange = result.isRequiringPasswordChange
            self.mfaSessionID = result.mfaSessionID
            self.selectedFactorType = nil
            self.webauthnRequestOptions = nil
            
            // Backend currently requires MFA if allowedFactors is returned. 
            // Usually MFA is mandatory, so we proceed to factor selection.
            self.state = .mfaRequired(allowedFactors: result.allowedFactors)
            return true
        } catch {
            if let authErr = error as? AuthError, case .deviceMismatch = authErr {
                try? DeviceIDStore.shared.reset()
            }
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    /// Step 2: Select a factor (totp, email_otp, phone_otp). Returns `true` if challenge sent successfully.
    public func selectFactor(factor: String) async -> Bool {
        guard let sID = mfaSessionID else { return false }
        
        state = .loading("Requesting challenge...")
        do {
            let result = try await authRepository.selectLoginFactor(mfaSessionID: sID, factor: factor)
            if factor == "webauthn" && result.webauthnRequestOptions.isEmpty {
                let message = "The server did not return passkey request options."
                self.state = .error(message)
                self.errorMessage = message
                return false
            }
            self.selectedFactorType = factor
            self.webauthnRequestOptions = result.webauthnRequestOptions.isEmpty ? nil : result.webauthnRequestOptions
            self.state = .mfaChallengeReceived(factor: factor, target: result.challengeSent ? result.challengeTarget : nil)
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func verifyPasskey() async -> Bool {
        guard let sID = mfaSessionID, selectedFactorType == "webauthn" else { return false }
        guard let requestOptions = webauthnRequestOptions, !requestOptions.isEmpty else {
            let message = "The server did not return passkey request options."
            self.state = .error(message)
            self.errorMessage = message
            return false
        }

        state = .loading("Waiting for Face ID...")
        do {
            let assertion = try await passkeyManager.getAssertion(from: requestOptions)
            state = .loading("Verifying passkey...")

            let tokens = try await authRepository.verifyLoginMFA(
                mfaSessionID: sID,
                factorSelection: .webauthnAssertion(assertion)
            )

            try sessionManager.startSession(tokens: tokens)
            applyStagedQuickLoginPreferences(using: tokens)
            self.state = .success
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    /// Step 3: Verify the selected factor code (OTP or TOTP)
    public func verifyMFA(code: String) async -> Bool {
        guard let sID = mfaSessionID, let factorType = selectedFactorType else { return false }

        state = .loading("Verifying...")
        do {
            let factorSelection: Auth_V1_VerifyLoginMFARequest.OneOf_Factor
            
            switch factorType {
            case "totp":
                factorSelection = .totpCode(code)
            case "email_otp":
                factorSelection = .emailOtpCode(code)
            case "phone_otp":
                factorSelection = .phoneOtpCode(code)
            default:
                throw AuthError.unknown
            }

            let tokens = try await authRepository.verifyLoginMFA(mfaSessionID: sID, factorSelection: factorSelection)
            
            // Give session straight to SessionManager
            try sessionManager.startSession(tokens: tokens)
            applyStagedQuickLoginPreferences(using: tokens)
            
            self.state = .success
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    // UI Helpers
    public var allowedFactors: [String] {
        if case .mfaRequired(let factors) = state { return factors }
        if case .mfaChallengeReceived = state { return [selectedFactorType ?? ""] }
        return []
    }
    
    public var currentChallengeTarget: String? {
        if case .mfaChallengeReceived(_, let target) = state { return target }
        return nil
    }

    public var hasWebAuthnRequestOptions: Bool {
        !(webauthnRequestOptions?.isEmpty ?? true)
    }

    public var currentLoginIdentifier: String? {
        pendingIdentifier
    }

    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Loading..."
    }

    public func updatePasswordAndContinue(newPassword: String) async -> Bool {
        let trimmed = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.errorMessage = "New password cannot be empty."
            return false
        }
        guard let currentPassword = pendingPrimaryPassword, !currentPassword.isEmpty else {
            self.errorMessage = "Current password context missing. Please login again."
            return false
        }

        state = .loading("Updating password...")
        do {
            try await authRepository.changePassword(currentPassword: currentPassword, newPassword: trimmed)
            pendingPrimaryPassword = trimmed
            requiresPasswordChange = false
            state = .success
            return true
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func applyStagedQuickLoginPreferences(using tokens: Auth_V1_AuthTokens) {
        guard let identifier = pendingIdentifier,
              let userID = JWTClaimsDecoder.subject(from: tokens.accessToken),
              let stagedBiometricEnabled = quickLoginPreferencesStore.consumeStagedBiometricEnabled(for: identifier) else {
            return
        }

        quickLoginPreferencesStore.setBiometricEnabled(stagedBiometricEnabled, for: userID)
    }
}
