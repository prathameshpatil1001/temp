// SignupViewModel.swift
// lms_borrower/Auth
//
// Stateful orchestration for the multi-step signup flow.
// This view model persists across the entire NavigationStack route for signup.

import SwiftUI
import Combine

@available(iOS 18.0, *)
@MainActor
public final class SignupViewModel: ObservableObject {

    public enum State {
        case idle
        case loading(String)
        case error(String)
        case success
    }

    @Published public var state: State = .idle
    @Published public var errorMessage: String? // For alerts

    private let authRepository: AuthRepository

    // In-memory flow state
    public var registrationID: String?
    public var tempPhoneOTP: String?
    public var signupName: String?
    public var signupEmail: String?
    public var signupPhone: String?
    public var signupPassword: String?
    public var redirectToLoginAfterSignup: Bool = false

    @MainActor
    public init(
        authRepository: AuthRepository? = nil
    ) {
        self.authRepository = authRepository ?? AuthRepository()
    }

    /// Step 1: Submit details to initiate signup. Returns `true` if successful and we can proceed to OTP.
    public func initiateSignup(fullName: String, email: String, phone: String, password: String) async -> Bool {
        state = .loading("Creating account...")
        do {
            let regID = try await authRepository.initiateSignup(email: email, phone: phone, password: password)
            self.registrationID = regID
            self.signupName = fullName
            self.signupEmail = email
            self.signupPhone = phone
            self.signupPassword = password
            SessionStore.stageSignupProfile(name: fullName, email: email, phone: phone)
            self.state = .idle // Ready for next step
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    /// Step 2: Verify both email and phone OTP codes.
    /// Returns `true` if verified. Redirect behavior depends on token availability.
    public func verifyOTPs(emailCode: String, phoneCode: String) async -> Bool {
        guard let regID = registrationID else { return false }

        state = .loading("Verifying codes...")
        do {
            let tokens = try await authRepository.verifySignupOTP(
                registrationID: regID,
                emailCode: emailCode,
                phoneCode: phoneCode
            )
            if let tokens = tokens {
                // Backend issued tokens; start session immediately.
                try SessionManager.shared.startSession(tokens: tokens)
                self.redirectToLoginAfterSignup = false
            } else {
                // Backend verified OTPs but did not issue tokens yet.
                // Require user to sign in manually.
                self.redirectToLoginAfterSignup = true
            }
            self.state = .success
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func resendOTP() async {
        guard registrationID != nil else {
            errorMessage = "Cannot resend code. Please restart signup."
            return
        }
        state = .loading("Resending code...")
        // TODO: Replace with real API call: authRepository.resendSignupOTP(registrationID: regID)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        state = .idle
    }
    
    // UI Helpers
    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Loading..."
    }

    public var stagedBiometricIdentifiers: [String] {
        [signupEmail, signupPhone].compactMap { $0 }
    }
}
