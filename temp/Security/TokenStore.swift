// TokenStore.swift
// lms_borrower/Security
//
// Keychain-backed secure storage for JWT access and refresh tokens.
//
// SECURITY RULES:
//  - Tokens are stored in Keychain ONLY — never in UserDefaults or any file.
//  - Access token and refresh token are always written / cleared together (atomic pair).
//  - Tokens are never logged. Do NOT add logging for token values anywhere.
//  - On logout or auth failure, always call `TokenStore.shared.clearAll()` to
//    erase both tokens even if the network call failed.

import Foundation

// MARK: - TokenStore

/// Manages secure persistence of the JWT access token and refresh token pair.
///
/// All reads and writes go through the Keychain via `KeychainHelper`.
/// The two tokens form an atomic pair — they are always written together
/// via `save(accessToken:refreshToken:)` and cleared together via `clearAll()`.
///
/// Usage:
/// ```swift
/// // After a successful VerifyLoginMFA response:
/// try TokenStore.shared.save(
///     accessToken:  response.accessToken,
///     refreshToken: response.refreshToken
/// )
///
/// // To read the current access token for an authenticated RPC:
/// let token = try TokenStore.shared.accessToken()
///
/// // On logout or session failure:
/// try TokenStore.shared.clearAll()
/// ```
public final class TokenStore: Sendable {

    // MARK: Singleton

    /// Shared instance. Use this everywhere.
    public static let shared = TokenStore()

    // MARK: Private constants

private enum Keys {
        static let service      = "codes.chirag.dst-app.tokens"
        static let accessToken  = "accessToken"
        static let refreshToken = "refreshToken"

        // Legacy keys from borrower app — used for one-time migration.
        static let legacyService = "codes.chirag.lms-borrower.tokens"
    }

    // MARK: Init

    private init() {
        migrateFromLegacyIfNeeded()
    }

    // MARK: - Legacy Migration

    /// One-time migration: if tokens exist under the legacy borrower app
    /// Keychain service but not under the new DST service, copy them over
    /// and clear the legacy entries. This prevents data contamination when
    /// both apps are installed on the same device.
    private func migrateFromLegacyIfNeeded() {
        // If we already have tokens in the new service, migration is not needed.
        if hasStoredSession() { return }

        // Try to read from the legacy service.
        guard let legacyAccess = try? KeychainHelper.read(service: Keys.legacyService, account: Keys.accessToken),
              let legacyRefresh = try? KeychainHelper.read(service: Keys.legacyService, account: Keys.refreshToken),
              !legacyAccess.isEmpty, !legacyRefresh.isEmpty else {
            return
        }

        // Migrate to the new service.
        do {
            try KeychainHelper.save(legacyAccess, service: Keys.service, account: Keys.accessToken)
            try KeychainHelper.save(legacyRefresh, service: Keys.service, account: Keys.refreshToken)
            // Clear the legacy entries to prevent both apps seeing the same tokens.
            try? KeychainHelper.delete(service: Keys.legacyService, account: Keys.accessToken)
            try? KeychainHelper.delete(service: Keys.legacyService, account: Keys.refreshToken)
        } catch {
            // Migration failed silently — user will need to log in again.
        }
    }

    // MARK: Write — always atomic pair

    /// Persists the access token and refresh token pair to the Keychain.
    ///
    /// Both tokens are written unconditionally. If only one succeeds, `clearAll()`
    /// is called to prevent a stale half-pair from remaining in the Keychain.
    ///
    /// - Parameters:
    ///   - accessToken:  JWT access token. Must not be empty.
    ///   - refreshToken: JWT refresh token. Must not be empty.
    /// - Throws: `KeychainError` if either write fails.
    public func save(accessToken: String, refreshToken: String) throws {
        precondition(!accessToken.isEmpty, "TokenStore: access token must not be empty.")
        precondition(!refreshToken.isEmpty, "TokenStore: refresh token must not be empty.")

        do {
            try KeychainHelper.save(accessToken, service: Keys.service, account: Keys.accessToken)
            try KeychainHelper.save(refreshToken, service: Keys.service, account: Keys.refreshToken)
        } catch {
            // If saving failed midway, erase both to prevent a half-written pair.
            try? clearAll()
            throw error
        }
    }

    // MARK: Read

    /// Returns the stored JWT access token, or `nil` if no session exists.
    /// - Throws: `KeychainError` on read failure.
    public func accessToken() throws -> String? {
        try KeychainHelper.read(service: Keys.service, account: Keys.accessToken)
    }

    /// Returns the stored JWT refresh token, or `nil` if no session exists.
    /// - Throws: `KeychainError` on read failure.
    public func refreshToken() throws -> String? {
        try KeychainHelper.read(service: Keys.service, account: Keys.refreshToken)
    }

    /// Returns `true` if a stored session exists (both tokens are present).
    ///
    /// Does NOT validate that the tokens are still accepted by the backend.
    /// Use this only to decide whether to attempt a silent session restore.
    public func hasStoredSession() -> Bool {
        guard let access = try? accessToken(),
              let refresh = try? refreshToken() else {
            return false
        }
        return !access.isEmpty && !refresh.isEmpty
    }

    // MARK: Delete — always atomic pair

    /// Erases both the access token and refresh token from the Keychain.
    ///
    /// Call this on:
    ///  - Logout (even if the backend Logout RPC failed or timed out)
    ///  - RefreshToken failure (session is irrecoverable — force re-login)
    ///  - Any auth error that indicates the session has been revoked on the backend
    ///
    /// This method is deliberately lenient — individual item-not-found errors
    /// are swallowed so the other item is still deleted.
    public func clearAll() throws {
        var firstError: Error?

        do {
            try KeychainHelper.delete(service: Keys.service, account: Keys.accessToken)
        } catch {
            firstError = error
        }

        do {
            try KeychainHelper.delete(service: Keys.service, account: Keys.refreshToken)
        } catch {
            if firstError == nil { firstError = error }
        }

        if let error = firstError {
            throw error
        }
    }
}
