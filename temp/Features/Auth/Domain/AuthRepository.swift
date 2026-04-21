// AuthRepository.swift
// lms_borrower/Auth
//
// High-level abstraction for auth flows.
// ViewModels talk only to this repository, not to the gRPC client directly.
// The repository handles token reading, call options injection, and mapping 
// domain intents into gRPC requests.

import Foundation
import GRPCCore

@available(iOS 18.0, *)
@MainActor
public final class AuthRepository: Sendable {

    private let client: AuthGRPCClientProtocol
    private let tokenStore: TokenStore
    private let deviceStore: DeviceIDStore

    // MARK: - Init

    public nonisolated init(
        client: AuthGRPCClientProtocol = AuthGRPCClient(),
        tokenStore: TokenStore = .shared,
        deviceStore: DeviceIDStore = .shared
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.deviceStore = deviceStore
    }

    // MARK: - Signup Flow

    /// Initiates the signup process.
    /// Note: Name is ignored by the backend contract, so we don't send it.
    public func initiateSignup(email: String, phone: String, password: String) async throws -> String {
        var request = Auth_V1_SignupRequest()
        request.email = email
        request.phone = phone
        request.password = password
        request.role = .borrower

        let options = AuthCallOptionsFactory.unauthenticated()
        let response = try await client.initiateSignup(request: request, options: options)
        return response.registrationID
    }

    /// Verifies both email and phone OTPs to complete signup.
    public func verifySignupOTP(registrationID: String, emailCode: String, phoneCode: String) async throws -> Auth_V1_AuthTokens {
        var request = Auth_V1_VerifyOTPsRequest()
        request.registrationID = registrationID
        request.emailCode = emailCode
        request.phoneCode = phoneCode

        let options = AuthCallOptionsFactory.unauthenticated()
        let response = try await client.verifySignupOTPs(request: request, options: options)
        guard response.verified else {
            throw AuthError.invalidServerResponse("Signup verification failed.")
        }

        guard !response.accessToken.isEmpty, !response.refreshToken.isEmpty else {
            throw AuthError.invalidServerResponse("Signup verification succeeded but tokens were missing.")
        }

        var tokens = Auth_V1_AuthTokens()
        tokens.accessToken = response.accessToken
        tokens.refreshToken = response.refreshToken
        return tokens
    }

    // MARK: - Login Flow

    public struct PrimaryLoginResult {
        public let mfaSessionID: String
        public let allowedFactors: [String]
        public let isRequiringPasswordChange: Bool
    }

    public struct PasskeyRegistrationContext {
        public let userID: String
        public let creationOptionsJSON: Data
    }

    public struct PasskeyLoginContext {
        public let mfaSessionID: String
        public let requestOptionsJSON: Data
    }

    /// Step 1 of Login. Submits identifier/password and returns allowed MFA factors.
    public func loginPrimary(identifier: String, password: String) async throws -> PrimaryLoginResult {
        var request = Auth_V1_LoginRequest()
        request.emailOrPhone = identifier
        request.password = password

        let options = AuthCallOptionsFactory.unauthenticated()
        let response = try await client.loginPrimary(request: request, options: options)
        return PrimaryLoginResult(
            mfaSessionID: response.mfaSessionID,
            allowedFactors: response.allowedFactors,
            isRequiringPasswordChange: response.isRequiringPasswordChange
        )
    }

    public struct FactorSelectionResult {
        public let challengeSent: Bool
        public let challengeTarget: String
        public let webauthnRequestOptions: Data
    }

    /// Step 2 of Login. Selects the MFA factor.
    public func selectLoginFactor(mfaSessionID: String, factor: String) async throws -> FactorSelectionResult {
        var request = Auth_V1_SelectLoginMFAFactorRequest()
        request.mfaSessionID = mfaSessionID
        request.factor = factor

        let options = AuthCallOptionsFactory.unauthenticated()
        let response = try await client.selectLoginMFAFactor(request: request, options: options)
        return FactorSelectionResult(
            challengeSent: response.challengeSent,
            challengeTarget: response.challengeTarget,
            webauthnRequestOptions: response.webauthnRequestOptions
        )
    }

    /// Step 3 of Login. Verifies the MFA code and returns raw tokens (which SessionManager will persist).
    public func verifyLoginMFA(mfaSessionID: String, factorSelection: Auth_V1_VerifyLoginMFARequest.OneOf_Factor) async throws -> Auth_V1_AuthTokens {
        // Device ID is required here
        let deviceID = try deviceStore.getOrCreate()

        var request = Auth_V1_VerifyLoginMFARequest()
        request.mfaSessionID = mfaSessionID
        request.factor = factorSelection
        request.deviceID = deviceID

        let options = AuthCallOptionsFactory.unauthenticated()
        return try await client.verifyLoginMFA(request: request, options: options)
    }

    // MARK: - TOTP Setup (Authenticated)

    public struct TOTPSetupResult {
        public let secret: String
        public let provisioningURI: String
    }

    /// Step 1 of TOTP Setup (post-login).
    public func setupTOTP() async throws -> TOTPSetupResult { // Doesn't need registration_id for authenticated user
        guard let token = try tokenStore.accessToken() else { throw AuthError.unauthenticated }
        
        let request = Auth_V1_SetupTOTPRequest()
        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let response = try await client.setupTOTP(request: request, metadata: metadata, options: options)
        return TOTPSetupResult(secret: response.secret, provisioningURI: response.provisioningUri)
    }

    /// Step 2 of TOTP Setup. Verifies the code and returns refreshed tokens.
    public func verifyTOTPSetup(code: String) async throws -> Auth_V1_AuthTokens {
        guard let token = try tokenStore.accessToken() else { throw AuthError.unauthenticated }
        let deviceID = try deviceStore.getOrCreate()

        var request = Auth_V1_VerifyTOTPSetupRequest()
        request.code = code
        request.deviceID = deviceID

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        return try await client.verifyTOTPSetup(request: request, metadata: metadata, options: options)
    }

    // MARK: - Passkeys

    public func beginPasskeyRegistration() async throws -> PasskeyRegistrationContext {
        guard let token = try tokenStore.accessToken() else { throw AuthError.unauthenticated }
        guard let userID = JWTClaimsDecoder.subject(from: token) else {
            throw AuthError.invalidServerResponse("The current session is missing a user identifier for passkey setup.")
        }

        var request = Auth_V1_WebAuthnRegRequest()
        request.userID = userID

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let response = try await client.beginWebAuthnRegistration(
            request: request,
            metadata: metadata,
            options: options
        )

        return PasskeyRegistrationContext(
            userID: userID,
            creationOptionsJSON: response.publicKeyCredentialCreationOptions
        )
    }

    public func finishPasskeyRegistration(userID: String, credentialJSON: Data) async throws -> Auth_V1_AuthTokens {
        guard let token = try tokenStore.accessToken() else { throw AuthError.unauthenticated }
        let deviceID = try deviceStore.getOrCreate()

        var request = Auth_V1_WebAuthnFinishRegRequest()
        request.userID = userID
        request.credential = credentialJSON
        request.deviceID = deviceID

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        return try await client.finishWebAuthnRegistration(
            request: request,
            metadata: metadata,
            options: options
        )
    }

    public func beginPasskeyLogin(userID: String) async throws -> PasskeyLoginContext {
        var request = Auth_V1_WebAuthnLoginRequest()
        request.userID = userID

        let options = AuthCallOptionsFactory.unauthenticated()
        let response = try await client.beginWebAuthnLogin(request: request, options: options)

        return PasskeyLoginContext(
            mfaSessionID: response.mfaSessionID,
            requestOptionsJSON: response.publicKeyCredentialRequestOptions
        )
    }

    public func finishPasskeyLogin(mfaSessionID: String, assertionJSON: Data) async throws -> Auth_V1_AuthTokens {
        let deviceID = try deviceStore.getOrCreate()

        var request = Auth_V1_WebAuthnFinishLoginRequest()
        request.mfaSessionID = mfaSessionID
        request.assertion = assertionJSON
        request.deviceID = deviceID

        let options = AuthCallOptionsFactory.unauthenticated()
        return try await client.finishWebAuthnLogin(request: request, options: options)
    }

    // MARK: - Session Management

    /// Refreshes the session using the stored refresh token.
    public func refreshSession() async throws -> Auth_V1_AuthTokens {
        guard let refreshTokenStr = try tokenStore.refreshToken() else { throw AuthError.sessionExpired }
        let deviceID = try deviceStore.getOrCreate()

        var request = Auth_V1_RefreshTokenRequest()
        request.refreshToken = refreshTokenStr
        request.deviceID = deviceID

        let options = AuthCallOptionsFactory.forTokenRefresh()
        return try await client.refreshToken(request: request, options: options)
    }

    /// Best-effort logout call to the backend.
    public func logout() async throws {
        guard let access = try tokenStore.accessToken(),
              let refresh = try tokenStore.refreshToken() else {
            return
        }

        var request = Auth_V1_LogoutRequest()
        request.accessToken = access
        request.refreshToken = refresh

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: access, timeout: CallTimeout.logout)
        _ = try? await client.logout(request: request, metadata: metadata, options: options)
    }
}
