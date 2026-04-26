import Foundation

final class QuickLoginPreferencesStore {
    static let shared = QuickLoginPreferencesStore()

    private let defaults = UserDefaults.standard
    private let biometricPrefix = "dst_quick_login_biometric_enabled_"
    private let authenticatorPrefix = "dst_quick_login_authenticator_enabled_"
    private let stagedBiometricPrefix = "dst_staged_signup_biometric_enabled_"

    private init() {}

    func isBiometricEnabled(for userID: String) -> Bool {
        bool(forKey: biometricPrefix + userID, defaultValue: false)
    }

    func setBiometricEnabled(_ enabled: Bool, for userID: String) {
        defaults.set(enabled, forKey: biometricPrefix + userID)
    }

    func isAuthenticatorEnabled(for userID: String) -> Bool {
        bool(forKey: authenticatorPrefix + userID, defaultValue: false)
    }

    func setAuthenticatorEnabled(_ enabled: Bool, for userID: String) {
        defaults.set(enabled, forKey: authenticatorPrefix + userID)
    }

    func stageBiometricEnabled(_ enabled: Bool, for identifiers: [String]) {
        identifiers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .forEach { identifier in
                defaults.set(enabled, forKey: stagedBiometricPrefix + identifier)
            }
    }

    func consumeStagedBiometricEnabled(for identifier: String) -> Bool? {
        let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = stagedBiometricPrefix + normalizedIdentifier
        guard defaults.object(forKey: key) != nil else { return nil }
        let value = defaults.bool(forKey: key)
        defaults.removeObject(forKey: key)
        return value
    }

    private func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }
}