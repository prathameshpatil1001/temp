import Foundation

final class PasskeyStatusStore {
    static let shared = PasskeyStatusStore()

    private let defaults = UserDefaults.standard
    private let key = "dst_registered_passkey_user_ids"

    private init() {}

    func isPasskeyRegistered(for userID: String) -> Bool {
        registeredUserIDs.contains(userID)
    }

    func markPasskeyRegistered(for userID: String) {
        var ids = registeredUserIDs
        ids.insert(userID)
        defaults.set(Array(ids), forKey: key)
    }

    private var registeredUserIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }
}
