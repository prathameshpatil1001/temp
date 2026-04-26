import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class PasskeyManager: NSObject {
    static let shared = PasskeyManager()

    enum PasskeyError: LocalizedError {
        case invalidCreationOptions
        case invalidRequestOptions
        case invalidBase64URL
        case unsupportedCredential
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .invalidCreationOptions:
                return "The server returned invalid passkey registration options."
            case .invalidRequestOptions:
                return "The server returned invalid passkey sign-in options."
            case .invalidBase64URL:
                return "A passkey challenge could not be decoded."
            case .unsupportedCredential:
                return "The device returned an unsupported passkey credential."
            case .cancelled:
                return "The passkey prompt was cancelled."
            case .failed(let message):
                return message
            }
        }
    }

    private enum PendingOperation {
        case registration(CheckedContinuation<Data, Error>)
        case assertion(CheckedContinuation<Data, Error>)
    }

    private var pendingOperation: PendingOperation?

    func createCredential(from creationOptionsJSON: Data) async throws -> Data {
        let options: PublicKeyCredentialCreationOptions
        do {
            options = try JSONDecoder().decode(PublicKeyCredentialCreationOptions.self, from: creationOptionsJSON)
        } catch {
            throw PasskeyError.invalidCreationOptions
        }

        guard let challenge = Data(base64URLEncoded: options.challenge),
              let userID = Data(base64URLEncoded: options.user.id) else {
            throw PasskeyError.invalidBase64URL
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.rp.id
        )
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: options.user.name,
            userID: userID
        )

        return try await perform(operation: .registrationPlaceholder, requests: [request])
    }

    func getAssertion(from requestOptionsJSON: Data) async throws -> Data {
        let options: PublicKeyCredentialRequestOptions
        do {
            options = try JSONDecoder().decode(PublicKeyCredentialRequestOptions.self, from: requestOptionsJSON)
        } catch {
            throw PasskeyError.invalidRequestOptions
        }

        guard let challenge = Data(base64URLEncoded: options.challenge) else {
            throw PasskeyError.invalidBase64URL
        }

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.rpID
        )
        let request = provider.createCredentialAssertionRequest(challenge: challenge)

        if !options.allowCredentials.isEmpty {
            request.allowedCredentials = options.allowCredentials.compactMap { allowedCredential in
                guard let credentialID = Data(base64URLEncoded: allowedCredential.id) else { return nil }
                return ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credentialID)
            }
        }

        return try await perform(operation: .assertionPlaceholder, requests: [request])
    }

    private enum ContinuationMarker {
        case registrationPlaceholder
        case assertionPlaceholder
    }

    private func perform(
        operation: ContinuationMarker,
        requests: [ASAuthorizationRequest]
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            switch operation {
            case .registrationPlaceholder:
                pendingOperation = .registration(continuation)
            case .assertionPlaceholder:
                pendingOperation = .assertion(continuation)
            }

            let controller = ASAuthorizationController(authorizationRequests: requests)
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(with result: Result<Data, Error>) {
        guard let operation = pendingOperation else { return }
        pendingOperation = nil

        switch operation {
        case .registration(let continuation):
            continuation.resume(with: result)
        case .assertion(let continuation):
            continuation.resume(with: result)
        }
    }
}

extension PasskeyManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            do {
                finish(with: .success(try RegistrationCredentialPayload(credential: credential).encoded()))
            } catch {
                finish(with: .failure(error))
            }
            return
        }

        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            do {
                finish(with: .success(try AssertionCredentialPayload(credential: credential).encoded()))
            } catch {
                finish(with: .failure(error))
            }
            return
        }

        finish(with: .failure(PasskeyError.unsupportedCredential))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError,
           authError.code == .canceled {
            finish(with: .failure(PasskeyError.cancelled))
            return
        }

        finish(with: .failure(PasskeyError.failed(error.localizedDescription)))
    }
}

extension PasskeyManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow) ?? UIWindow()
    }
}

private struct PublicKeyCredentialCreationOptions: Decodable {
    struct RelyingParty: Decodable {
        let id: String
        let name: String
    }

    struct User: Decodable {
        let id: String
        let name: String
        let displayName: String

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case displayName
        }
    }

    let challenge: String
    let rp: RelyingParty
    let user: User
}

private struct PublicKeyCredentialRequestOptions: Decodable {
    struct AllowedCredential: Decodable {
        let id: String
        let type: String
    }

    let challenge: String
    let rpID: String
    let allowCredentials: [AllowedCredential]

    private enum CodingKeys: String, CodingKey {
        case challenge
        case rpID = "rpId"
        case allowCredentials
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        challenge = try container.decode(String.self, forKey: .challenge)
        rpID = try container.decodeIfPresent(String.self, forKey: .rpID) ?? "localhost"
        allowCredentials = try container.decodeIfPresent([AllowedCredential].self, forKey: .allowCredentials) ?? []
    }
}

private struct RegistrationCredentialPayload: Encodable {
    struct Response: Encodable {
        let attestationObject: String
        let clientDataJSON: String
    }

    let id: String
    let rawID: String
    let type = "public-key"
    let response: Response
    let clientExtensionResults: [String: String] = [:]
    let authenticatorAttachment = "platform"

    init(credential: ASAuthorizationPlatformPublicKeyCredentialRegistration) throws {
        guard let attestationObject = credential.rawAttestationObject else {
            throw PasskeyManager.PasskeyError.unsupportedCredential
        }

        let credentialID = credential.credentialID.base64URLEncodedString()
        id = credentialID
        rawID = credentialID
        response = Response(
            attestationObject: attestationObject.base64URLEncodedString(),
            clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString()
        )
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rawID = "rawId"
        case type
        case response
        case clientExtensionResults
        case authenticatorAttachment
    }
}

private struct AssertionCredentialPayload: Encodable {
    struct Response: Encodable {
        let clientDataJSON: String
        let authenticatorData: String
        let signature: String
        let userHandle: String?
    }

    let id: String
    let rawID: String
    let type = "public-key"
    let response: Response
    let clientExtensionResults: [String: String] = [:]
    let authenticatorAttachment = "platform"

    init(credential: ASAuthorizationPlatformPublicKeyCredentialAssertion) {
        let credentialID = credential.credentialID.base64URLEncodedString()
        id = credentialID
        rawID = credentialID
        response = Response(
            clientDataJSON: credential.rawClientDataJSON.base64URLEncodedString(),
            authenticatorData: credential.rawAuthenticatorData.base64URLEncodedString(),
            signature: credential.signature.base64URLEncodedString(),
            userHandle: nil
        )
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rawID = "rawId"
        case type
        case response
        case clientExtensionResults
        case authenticatorAttachment
    }
}
