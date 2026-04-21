// DeviceIDStore.swift
// lms_borrower/Security
//
// Keychain-backed stable device identifier used in gRPC auth RPCs.
//
// WHY THIS EXISTS:
//  The backend requires a `device_id` string in these RPCs:
//    - VerifyLoginMFA
//    - VerifyTOTPSetup
//    - RefreshToken
//
//  The device_id is a stable, randomly-generated UUID that is:
//    - Created once on first app launch
//    - Stored in Keychain (survives app reinstall if Keychain is preserved)
//    - Regenerated only if the Keychain item is explicitly cleared
//    - Never synced to iCloud or included in backups
//    - Never logged or transmitted except as a gRPC call parameter
//
//  It is NOT a hardware identifier (IDFA, IDFV) — it is an app-scoped opaque ID
//  that lets the backend track which device a session belongs to.

import Foundation

// MARK: - DeviceIDStore

/// Manages the stable, Keychain-backed device identifier for this app installation.
///
/// `getOrCreate()` is the primary API — call it every time you need a `device_id`
/// for a gRPC request. It is safe to call repeatedly; the same UUID is returned
/// on every call after the first.
///
/// ```swift
/// let deviceID = try DeviceIDStore.shared.getOrCreate()
/// // Use deviceID in VerifyLoginMFARequest, RefreshTokenRequest, VerifyTOTPSetupRequest.
/// ```
public final class DeviceIDStore: Sendable {

    // MARK: Singleton

    /// Shared instance. Use this everywhere.
    public static let shared = DeviceIDStore()

    // MARK: Private constants

    private enum Keys {
        static let service   = "codes.chirag.lms-borrower.device"
        static let deviceID  = "deviceID"
    }

    // MARK: Init

    private init() {}

    // MARK: Public API

    /// Returns the device ID for this installation, creating it if it does not yet exist.
    ///
    /// On the very first call after install:
    ///  1. A new random UUID is generated via `UUID().uuidString`.
    ///  2. It is written to the Keychain.
    ///  3. The same UUID is returned on every subsequent call.
    ///
    /// On subsequent calls:
    ///  - The UUID is read from the Keychain and returned.
    ///
    /// - Returns: A stable UUID string, e.g. `"550E8400-E29B-41D4-A716-446655440000"`.
    /// - Throws: `KeychainError` if the Keychain read or write fails.
    public func getOrCreate() throws -> String {
        // Try to read an existing device ID.
        if let existing = try KeychainHelper.read(service: Keys.service, account: Keys.deviceID),
           !existing.isEmpty {
            return existing
        }

        // None exists — generate and persist a new one.
        let newID = UUID().uuidString
        try KeychainHelper.save(newID, service: Keys.service, account: Keys.deviceID)
        return newID
    }

    /// Reads the current device ID without creating one if absent.
    ///
    /// Returns `nil` if the device ID has not been created yet.
    /// In normal operation, prefer `getOrCreate()`.
    public func current() throws -> String? {
        try KeychainHelper.read(service: Keys.service, account: Keys.deviceID)
    }

    // MARK: Reset

    /// Deletes the stored device ID from the Keychain.
    ///
    /// After calling this, the next call to `getOrCreate()` will generate a
    /// new UUID, which will create a new device identity on the backend.
    ///
    /// When to call:
    ///  - App-level "reset all data" / "sign out and clear everything" flow.
    ///  - When the backend rejects the device_id with an unrecoverable error.
    ///
    /// Do NOT call this on a normal logout — the device_id should persist
    /// across logout/login cycles for the same physical device.
    public func reset() throws {
        try KeychainHelper.delete(service: Keys.service, account: Keys.deviceID)
    }
}
