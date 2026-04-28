import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published private(set) var accessToken: String = ""
    @Published private(set) var refreshToken: String = ""
    @Published private(set) var deviceID: String

    private init() {
        if let existing = UserDefaults.standard.string(forKey: "lms.device_id"), !existing.isEmpty {
            self.deviceID = existing
        } else {
            let created = UUID().uuidString
            UserDefaults.standard.set(created, forKey: "lms.device_id")
            self.deviceID = created
        }
    }

    var hasAccessToken: Bool {
        !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func clear() {
        self.accessToken = ""
        self.refreshToken = ""
    }
}
