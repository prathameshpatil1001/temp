import GRPCCore
import SwiftUI
import Combine

@available(iOS 18.0, *)
@MainActor
final class PasskeySetupViewModel: ObservableObject {
    enum State {
        case idle
        case loading(String)
        case success
        case error(String)
    }

    @Published var state: State = .idle
    @Published var errorMessage: String?

    private let authRepository: AuthRepository
    private let passkeyManager: PasskeyManager
    private let tokenStore: TokenStore
    private let passkeyStatusStore: PasskeyStatusStore

    init(
        authRepository: AuthRepository? = nil,
        passkeyManager: PasskeyManager = .shared,
        tokenStore: TokenStore = .shared,
        passkeyStatusStore: PasskeyStatusStore = .shared
    ) {
        self.authRepository = authRepository ?? AuthRepository()
        self.passkeyManager = passkeyManager
        self.tokenStore = tokenStore
        self.passkeyStatusStore = passkeyStatusStore
    }

    func registerPasskey() async -> Bool {
        state = .loading("Preparing passkey...")

        do {
            let registration = try await authRepository.beginPasskeyRegistration()

            state = .loading("Waiting for Face ID...")
            let credentialJSON = try await passkeyManager.createCredential(
                from: registration.creationOptionsJSON
            )

            state = .loading("Finishing setup...")
            _ = try await authRepository.finishPasskeyRegistration(
                userID: registration.userID,
                credentialJSON: credentialJSON
            )

            passkeyStatusStore.markPasskeyRegistered(for: registration.userID)
            state = .success
            return true
        } catch let error as AuthError {
            let message = friendlyMessage(for: error)
            state = .error(message)
            errorMessage = message
            return false
        } catch {
            let message = error.localizedDescription
            state = .error(message)
            errorMessage = message
            return false
        }
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Set Up Passkey"
    }

    var isConfiguredLocally: Bool {
        guard let accessToken = try? tokenStore.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            return false
        }

        return passkeyStatusStore.isPasskeyRegistered(for: userID)
    }

    private func friendlyMessage(for error: AuthError) -> String {
        if case .underlyingError(let rpc) = error {
            switch rpc.code {
            case .unimplemented:
                return "The iPhone passkey prompt is wired in, but the backend has not finished the WebAuthn registration endpoint yet."
            case .failedPrecondition:
                return "Passkey setup could not start because the server-side registration session was unavailable."
            default:
                break
            }
        }

        return error.localizedDescription
    }
}
