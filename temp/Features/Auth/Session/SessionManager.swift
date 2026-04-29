// SessionManager.swift
// lms_borrower/Auth
//
// Central brain for session lifecycle orchestration.
// Coordinates TokenStore, DeviceIDStore, and AuthRepository to manage
// the user's logged-in state, silent token refreshes, and secure logout.

import Foundation

@available(iOS 18.0, *)
@MainActor
public final class SessionManager: Sendable {
    
    // MARK: Singleton
    public static let shared = SessionManager()
    
    // MARK: Dependencies
    private let tokenStore: TokenStore
    private let authRepository: AuthRepository
    private let deviceStore: DeviceIDStore
    
    // Since we need to update the UI, we keep a weak or injected reference to the SessionStore
    // However, to keep it loosely coupled, SessionStore will observe or call into SessionManager.
    // We'll expose state through async signals or explicit calls.
    
    @MainActor
    private init(
        tokenStore: TokenStore = .shared,
        authRepository: AuthRepository? = nil,
        deviceStore: DeviceIDStore = .shared
    ) {
        self.tokenStore = tokenStore
        self.authRepository = authRepository ?? AuthRepository()
        self.deviceStore = deviceStore
    }
    
    // MARK: - Lifecycle Auth
    
    /// Attempts to silently restore the session.
    ///
    /// Since the backend has disabled the RefreshToken RPC, silent restoration
    /// is not possible. The user must always re-authenticate via InitiateReopen + MFA.
    /// This method always returns `false` and does NOT clear tokens or post
    /// the `.sessionExpired` notification.
    public func attemptSilentRestore(notifyOnFailure: Bool = true) async -> Bool {
        // RefreshToken is disabled on the backend. Silent restore is not possible.
        // Return false without clearing tokens — the user will be presented with
        // the QuickLoginGate and must re-authenticate via InitiateReopen + MFA.
        return false
    }
    
    /// Call this when the user successfully authenticates via MFA or new signup auto-login.
    public func startSession(tokens: Auth_V1_AuthTokens) throws {
        try tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
    }
    
    /// Securely logs the user out.
    /// Best effort network call, but strictly clears local keychain regardless.
    public func logout() async {
        if tokenStore.hasStoredSession() {
            _ = try? await authRepository.logout()
        }
        try? tokenStore.clearAll()
    }
}

public extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}
