import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case hindi = "hi"
    case marathi = "mr"
    case tamil = "ta"
    case telugu = "te"

    static let storageKey = "selectedLanguageCode"
    static let defaultLanguage: AppLanguage = .english

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .english:
            return "English"
        case .hindi:
            return "Hindi (हिन्दी)"
        case .marathi:
            return "Marathi (मराठी)"
        case .tamil:
            return "Tamil (தமிழ்)"
        case .telugu:
            return "Telugu (తెలుగు)"
        }
    }

    static func from(storageValue: String) -> AppLanguage {
        AppLanguage(rawValue: storageValue) ?? defaultLanguage
    }
}
