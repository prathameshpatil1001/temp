import SwiftUI

// MARK: - Main Settings View
struct SettingsView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject private var session: SessionStore
    @AppStorage(AppLanguage.storageKey) private var selectedLanguageCode = AppLanguage.defaultLanguage.rawValue
    @State private var notificationsEnabled = true
    @State private var activeSheet: SecuritySheet?
    @State private var isAuthenticatorQuickLoginEnabled = false
    @State private var didCompleteAuthenticatorSetup = false
    @State private var alertContext: SettingsAlertContext?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Preferences
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferences").font(.caption).foregroundColor(.secondary).padding(.horizontal, 20)
                    VStack(spacing: 0) {
                        SettingsNavRow(icon: "globe", title: "Language", value: selectedLanguage.displayNameKey) { router.push(.languageSelection) }
                        Divider().padding(.leading, 56)
                        SettingsNavRow(icon: "figure.accessibility", title: "Accessibility") { router.push(.accessibilitySettings) }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                
                // Security
                VStack(alignment: .leading, spacing: 8) {
                    Text("Security").font(.caption).foregroundColor(.secondary).padding(.horizontal, 20)
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "checkmark.shield.fill",
                            title: "Authenticator App",
                            isOn: authenticatorToggleBinding
                        )
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }
                
                // Alerts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alerts").font(.caption).foregroundColor(.secondary).padding(.horizontal, 20)
                    VStack(spacing: 0) {
                        SettingsToggleRow(icon: "bell.fill", title: "Push Notifications", isOn: $notificationsEnabled)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }

                Button {
                    session.logout()
                } label: {
                    Text("Log Out")
                        .font(.headline)
                        .foregroundColor(.alertRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)

            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet, onDismiss: handleSheetDismiss) { sheet in
            switch sheet {
            case .authenticator:
                SetupTOTPView {
                    didCompleteAuthenticatorSetup = true
                    isAuthenticatorQuickLoginEnabled = true
                    persistAuthenticatorPreference(true)
                }
            }
        }
        .onAppear(perform: refreshState)
        .alert(item: $alertContext) { context in
            switch context {
            case .disableAuthenticator:
                return Alert(
                    title: Text("Turn Off Authenticator App?"),
                    message: Text("This will disable authenticator-based quick login on this device."),
                    primaryButton: .destructive(Text("Turn Off")) {
                        isAuthenticatorQuickLoginEnabled = false
                        persistAuthenticatorPreference(false)
                    },
                    secondaryButton: .cancel {
                        isAuthenticatorQuickLoginEnabled = true
                    }
                )
            case .activeUserVerificationFailed:
                return Alert(
                    title: Text("Settings"),
                    message: Text("We couldn't verify the active user for this setting."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage.from(storageValue: selectedLanguageCode)
    }

    private var authenticatorToggleBinding: Binding<Bool> {
        Binding(
            get: { isAuthenticatorQuickLoginEnabled },
            set: handleAuthenticatorToggleChange
        )
    }

    private func refreshState() {
        guard let userID = currentUserID else {
            isAuthenticatorQuickLoginEnabled = false
            return
        }

        isAuthenticatorQuickLoginEnabled = QuickLoginPreferencesStore.shared.isAuthenticatorEnabled(for: userID)
    }

    private var currentUserID: String? {
        guard let accessToken = try? TokenStore.shared.accessToken() else { return nil }
        return JWTClaimsDecoder.subject(from: accessToken)
    }

    private func handleSheetDismiss() {
        if activeSheet == nil, !didCompleteAuthenticatorSetup {
            refreshAuthenticatorPreference()
        }
        didCompleteAuthenticatorSetup = false
    }

    private func handleAuthenticatorToggleChange(_ newValue: Bool) {
        if newValue {
            didCompleteAuthenticatorSetup = false
            activeSheet = .authenticator
        } else {
            alertContext = .disableAuthenticator
        }
    }

    private func refreshAuthenticatorPreference() {
        guard let userID = currentUserID else {
            isAuthenticatorQuickLoginEnabled = false
            return
        }
        isAuthenticatorQuickLoginEnabled = QuickLoginPreferencesStore.shared.isAuthenticatorEnabled(for: userID)
    }

    private func persistAuthenticatorPreference(_ enabled: Bool) {
        guard let userID = currentUserID else {
            alertContext = .activeUserVerificationFailed
            return
        }
        QuickLoginPreferencesStore.shared.setAuthenticatorEnabled(enabled, for: userID)
    }
}

private enum SecuritySheet: String, Identifiable {
    case authenticator

    var id: String { rawValue }
}

private enum SettingsAlertContext: Identifiable {
    case disableAuthenticator
    case activeUserVerificationFailed

    var id: String {
        switch self {
        case .disableAuthenticator:
            return "disable-authenticator"
        case .activeUserVerificationFailed:
            return "active-user-verification-failed"
        }
    }
}

// MARK: - Language Selection View
struct LanguageSelectionView: View {
    @AppStorage(AppLanguage.storageKey) private var selectedLanguageCode = AppLanguage.defaultLanguage.rawValue
    private let languages = AppLanguage.allCases
    
    var body: some View {
        List {
            ForEach(languages) { language in
                Button {
                    selectedLanguageCode = language.rawValue
                } label: {
                    HStack {
                        Text(language.displayNameKey).foregroundColor(.primary)
                        Spacer()
                        if selectedLanguageCode == language.rawValue {
                            Image(systemName: "checkmark").foregroundColor(.mainBlue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Accessibility Settings View
struct AccessibilitySettingsView: View {
    @State private var highContrast = false
    @State private var reduceMotion = false
    @State private var textSize: Double = 1.0
    
    var body: some View {
        Form {
            Section(header: Text("Display")) {
                Toggle("High Contrast Mode", isOn: $highContrast)
                    .tint(.mainBlue)
                
                VStack(alignment: .leading) {
                    Text("Text Size")
                    Slider(value: $textSize, in: 0.8...1.5, step: 0.1)
                        .accentColor(.mainBlue)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Animations")) {
                Toggle("Reduce Motion", isOn: $reduceMotion)
                    .tint(.mainBlue)
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Settings Subcomponents
struct SettingsNavRow: View {
    let icon: String
    let title: LocalizedStringKey
    var value: LocalizedStringKey? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title3).foregroundColor(.mainBlue).frame(width: 24)
                Text(title).font(.body).foregroundColor(.primary)
                Spacer()
                if let val = value { Text(val).font(.subheadline).foregroundColor(.secondary) }
                Image(systemName: "chevron.right").font(.subheadline).foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3).foregroundColor(.mainBlue).frame(width: 24)
            Toggle(title, isOn: $isOn)
                .font(.body)
                .tint(.mainBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let title: LocalizedStringKey
    let value: LocalizedStringKey

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3).foregroundColor(.mainBlue).frame(width: 24)
            Text(title).font(.body).foregroundColor(.primary)
            Spacer()
            Text(value).font(.subheadline).foregroundColor(.secondary)
        }
        .padding(16)
    }
}
