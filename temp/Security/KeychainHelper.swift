// KeychainHelper.swift
// lms_borrower/Security
//
// Low-level Keychain read/write/delete wrapper.
// All Security module calls are centralised here so the rest of the app
// never imports Security directly or touches raw CFDictionary APIs.
//
// SECURITY RULES:
//  - Items are stored with kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
//    so they survive app restarts but are never backed up to iCloud/iTunes.
//  - Do NOT change the accessibility setting without a security review.
//  - Do NOT log item values anywhere in this file.

import Foundation
import Security

// MARK: - KeychainError

/// Errors produced by `KeychainHelper` operations.
public enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedDataFormat
    case itemNotFound

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):   return "Keychain save failed (OSStatus \(status))."
        case .readFailed(let status):   return "Keychain read failed (OSStatus \(status))."
        case .deleteFailed(let status): return "Keychain delete failed (OSStatus \(status))."
        case .unexpectedDataFormat:     return "Keychain item data was not in the expected format."
        case .itemNotFound:             return "Keychain item not found."
        }
    }
}

// MARK: - KeychainHelper

/// Provides simple save / read / delete for string values in the Keychain.
///
/// Each item is keyed by a service string (`kSecAttrService`) and an account
/// string (`kSecAttrAccount`). The combination must be unique per stored secret.
///
/// Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// - Survives device reboot (available after first unlock).
/// - Bound to this device only — NOT synced to iCloud or included in backups.
public enum KeychainHelper {

    // MARK: Save

    /// Saves or updates a UTF-8 string value in the Keychain.
    ///
    /// If an item with the same service+account already exists it is overwritten
    /// atomically via `SecItemUpdate`.
    ///
    /// - Parameters:
    ///   - value: The string to store. Must not be empty.
    ///   - service: Keychain service identifier (e.g. `"codes.chirag.lms-borrower.tokens"`).
    ///   - account: Keychain account identifier (e.g. `"accessToken"`).
    /// - Throws: `KeychainError.saveFailed` if the underlying Security call fails.
    public static func save(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.unexpectedDataFormat
        }

        // Try update first (item may already exist).
        let query = baseQuery(service: service, account: account)
        let attributes: [CFString: Any] = [kSecValueData: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item does not exist yet — add it.
            var addQuery = baseQuery(service: service, account: account)
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(updateStatus)
        }
    }

    // MARK: Read

    /// Reads a UTF-8 string value from the Keychain.
    ///
    /// - Parameters:
    ///   - service: Keychain service identifier.
    ///   - account: Keychain account identifier.
    /// - Returns: The stored string, or `nil` if the item does not exist.
    /// - Throws: `KeychainError.readFailed` or `.unexpectedDataFormat` on failure.
    public static func read(service: String, account: String) throws -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedDataFormat
        }

        return string
    }

    // MARK: Delete

    /// Deletes an item from the Keychain.
    ///
    /// If the item does not exist, this call succeeds silently (idempotent).
    ///
    /// - Parameters:
    ///   - service: Keychain service identifier.
    ///   - account: Keychain account identifier.
    /// - Throws: `KeychainError.deleteFailed` on failure.
    public static func delete(service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: Private helpers

    private static func baseQuery(service: String, account: String) -> [CFString: Any] {
        return [
            kSecClass:      kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}
