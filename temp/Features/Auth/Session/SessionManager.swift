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
    
    /// Attempts to silently restore the session by refreshing the access token.
    ///
    /// - Parameter notifyOnFailure: When `true` (the default), posts the global
    ///   `.sessionExpired` notification if the refresh fails, causing the app to
    ///   route the user to the login screen. Pass `false` when the caller handles
    ///   the failure itself (e.g. TOTP setup, which retries locally and must not
    ///   trigger a premature logout).
    /// - Returns: `true` if a valid session was restored, `false` otherwise.
    public func attemptSilentRestore(notifyOnFailure: Bool = true) async -> Bool {
        if !tokenStore.hasStoredSession() {
            return false
        }
        
        do {
            let tokens = try await authRepository.refreshSession()
            try tokenStore.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            return true
        } catch {
            // Only broadcast the global notification when the caller has no
            // local recovery path – i.e. this is a true, unrecoverable expiry.
            if notifyOnFailure {
                NotificationCenter.default.post(name: .sessionExpired, object: nil)
            }
            try? tokenStore.clearAll()
            return false
        }
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
