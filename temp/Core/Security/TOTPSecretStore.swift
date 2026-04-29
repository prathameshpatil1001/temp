// TOTPSecretStore.swift
// Stores per-user TOTP secrets securely for local quick-login verification.

import Foundation

public final class TOTPSecretStore: Sendable {
    public static let shared = TOTPSecretStore()
    private let service = "codes.chirag.lms-borrower.totp"

    private init() {}

    public func save(secret: String, for userID: String) throws {
        try KeychainHelper.save(secret, service: service, account: userID)
    }

    public func secret(for userID: String) throws -> String? {
        try KeychainHelper.read(service: service, account: userID)
    }

    public func delete(for userID: String) throws {
        try KeychainHelper.delete(service: service, account: userID)
    }
}
