// SetupTOTPViewModel.swift
// lms_borrower/Auth
//
// Stateful orchestration for setting up an Authenticator app post-login.

import SwiftUI
import Combine

@available(iOS 18.0, *)
@MainActor
public final class SetupTOTPViewModel: ObservableObject {

    public enum State {
        case idle
        case loading(String)
        case error(String)
        case secretReceived(secret: String, provisioningURI: String)
        case success
    }

    @Published public var state: State = .idle
    @Published public var errorMessage: String? // For alerts

    private let authRepository: AuthRepository
    private let sessionManager: SessionManager

    @MainActor
    public init(
        authRepository: AuthRepository? = nil,
        sessionManager: SessionManager = .shared
    ) {
        self.authRepository = authRepository ?? AuthRepository()
        self.sessionManager = sessionManager
    }

    /// Step 1: Request the backend to generate a new TOTP secret.
    public func fetchSecret() async {
        state = .loading("Generating QR code...")
        do {
            let result = try await authRepository.setupTOTP()
            self.state = .secretReceived(secret: result.secret, provisioningURI: result.provisioningURI)
        } catch let error as AuthError {
            if case .sessionExpired = error {
                let restored = await sessionManager.attemptSilentRestore(notifyOnFailure: false)
                if restored {
                    do {
                        let result = try await authRepository.setupTOTP()
                        self.state = .secretReceived(secret: result.secret, provisioningURI: result.provisioningURI)
                        return
                    } catch {
                        self.state = .error(error.localizedDescription)
                        self.errorMessage = error.localizedDescription
                        return
                    }
                }
            }
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }

    /// Step 2: Verify the generated code and complete setup.
    public func verify(code: String) async -> Bool {
        state = .loading("Verifying code...")
        do {
            return try await attemptVerify(code: code)
        } catch let error as AuthError {
            if case .sessionExpired = error {
                let restored = await sessionManager.attemptSilentRestore(notifyOnFailure: false)
                if restored {
                    do {
                        return try await attemptVerify(code: code)
                    } catch {
                        self.state = .error(error.localizedDescription)
                        self.errorMessage = error.localizedDescription
                        return false
                    }
                }
            }
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    private func attemptVerify(code: String) async throws -> Bool {
        let tokens = try await authRepository.verifyTOTPSetup(code: code)
        try sessionManager.startSession(tokens: tokens)
        self.state = .success
        return true
    }
    
    // UI Helpers
    
    public var currentProvisioningURI: String? {
        if case .secretReceived(_, let uri) = state { return uri }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Loading..."
    }
}
