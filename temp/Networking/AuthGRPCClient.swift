// AuthGRPCClient.swift
// lms_borrower/Networking
//
// Low-level wrapper around the generated gRPC Auth client.
// Does NOT know about view models or the UI — it only translates Swift methods
// into underlying gRPC calls using the shared GRPCClient.
//
// gRPC-Swift v2 API:
//   - The generated Client<Transport> takes ClientRequest<T> messages.
//   - Default `onResponse` closure returns `try response.message`.
//   - No GRPCChannel type — use GRPCClient<HTTP2ClientTransport.Posix>.

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

// MARK: - AuthError

/// Strongly typed errors specific to the Auth client.
public enum AuthError: Error, LocalizedError {
    case unauthenticated
    case invalidCredentials
    case sessionExpired
    case deviceMismatch
    case invalidServerResponse(String)
    case networkError(String)
    case underlyingError(RPCError)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:       return "You are not authenticated."
        case .invalidCredentials:    return "Invalid email or password."
        case .sessionExpired:        return "Your session has expired. Please log in again."
        case .deviceMismatch:        return "Device identity changed. Please log in again using primary credentials."
        case .invalidServerResponse(let msg): return msg
        case .networkError(let msg): return "Network error: \(msg)"
        case .underlyingError(let e): return e.message
        case .unknown:               return "An unknown error occurred."
        }
    }

    static func from(_ error: Error) -> AuthError {
        if let rpc = error as? RPCError {
            if rpc.message.lowercased().contains("device") || rpc.message.lowercased().contains("mismatch") {
                return .deviceMismatch
            }
            switch rpc.code {
            case .unauthenticated:            return .sessionExpired
            case .permissionDenied:           return .invalidCredentials
            case .unavailable, .deadlineExceeded: return .networkError(rpc.message)
            default:                          return .underlyingError(rpc)
            }
        }
        return .networkError(error.localizedDescription)
    }
}

// MARK: - AuthGRPCClientProtocol

@available(iOS 18.0, *)
public protocol AuthGRPCClientProtocol: Sendable {
    func initiateSignup(request: Auth_V1_SignupRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_SignupResponse
    func verifySignupOTPs(request: Auth_V1_VerifyOTPsRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_VerifyOTPsResponse
    func loginPrimary(request: Auth_V1_LoginRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_LoginPrimaryResponse
    func selectLoginMFAFactor(request: Auth_V1_SelectLoginMFAFactorRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_SelectLoginMFAFactorResponse
    func verifyLoginMFA(request: Auth_V1_VerifyLoginMFARequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_AuthTokens
    func setupTOTP(request: Auth_V1_SetupTOTPRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_SetupTOTPResponse
    func verifyTOTPSetup(request: Auth_V1_VerifyTOTPSetupRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_AuthTokens
    func beginWebAuthnRegistration(request: Auth_V1_WebAuthnRegRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_WebAuthnRegResponse
    func finishWebAuthnRegistration(request: Auth_V1_WebAuthnFinishRegRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_AuthTokens
    func beginWebAuthnLogin(request: Auth_V1_WebAuthnLoginRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_WebAuthnLoginResponse
    func finishWebAuthnLogin(request: Auth_V1_WebAuthnFinishLoginRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_AuthTokens
    func refreshToken(request: Auth_V1_RefreshTokenRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_AuthTokens
    func logout(request: Auth_V1_LogoutRequest, metadata: Metadata, options: CallOptions) async throws -> Auth_V1_LogoutResponse
}

extension AuthGRPCClientProtocol {
    // Default implementations to make metadata optional
    public func initiateSignup(request: Auth_V1_SignupRequest, options: CallOptions) async throws -> Auth_V1_SignupResponse {
        try await initiateSignup(request: request, metadata: Metadata(), options: options)
    }
    public func verifySignupOTPs(request: Auth_V1_VerifyOTPsRequest, options: CallOptions) async throws -> Auth_V1_VerifyOTPsResponse {
        try await verifySignupOTPs(request: request, metadata: Metadata(), options: options)
    }
    public func loginPrimary(request: Auth_V1_LoginRequest, options: CallOptions) async throws -> Auth_V1_LoginPrimaryResponse {
        try await loginPrimary(request: request, metadata: Metadata(), options: options)
    }
    public func selectLoginMFAFactor(request: Auth_V1_SelectLoginMFAFactorRequest, options: CallOptions) async throws -> Auth_V1_SelectLoginMFAFactorResponse {
        try await selectLoginMFAFactor(request: request, metadata: Metadata(), options: options)
    }
    public func verifyLoginMFA(request: Auth_V1_VerifyLoginMFARequest, options: CallOptions) async throws -> Auth_V1_AuthTokens {
        try await verifyLoginMFA(request: request, metadata: Metadata(), options: options)
    }
    public func setupTOTP(request: Auth_V1_SetupTOTPRequest, options: CallOptions) async throws -> Auth_V1_SetupTOTPResponse {
        try await setupTOTP(request: request, metadata: Metadata(), options: options)
    }
    public func verifyTOTPSetup(request: Auth_V1_VerifyTOTPSetupRequest, options: CallOptions) async throws -> Auth_V1_AuthTokens {
        try await verifyTOTPSetup(request: request, metadata: Metadata(), options: options)
    }
    public func beginWebAuthnRegistration(request: Auth_V1_WebAuthnRegRequest, options: CallOptions) async throws -> Auth_V1_WebAuthnRegResponse {
        try await beginWebAuthnRegistration(request: request, metadata: Metadata(), options: options)
    }
    public func finishWebAuthnRegistration(request: Auth_V1_WebAuthnFinishRegRequest, options: CallOptions) async throws -> Auth_V1_AuthTokens {
        try await finishWebAuthnRegistration(request: request, metadata: Metadata(), options: options)
    }
    public func beginWebAuthnLogin(request: Auth_V1_WebAuthnLoginRequest, options: CallOptions) async throws -> Auth_V1_WebAuthnLoginResponse {
        try await beginWebAuthnLogin(request: request, metadata: Metadata(), options: options)
    }
    public func finishWebAuthnLogin(request: Auth_V1_WebAuthnFinishLoginRequest, options: CallOptions) async throws -> Auth_V1_AuthTokens {
        try await finishWebAuthnLogin(request: request, metadata: Metadata(), options: options)
    }
    public func refreshToken(request: Auth_V1_RefreshTokenRequest, options: CallOptions) async throws -> Auth_V1_AuthTokens {
        try await refreshToken(request: request, metadata: Metadata(), options: options)
    }
    public func logout(request: Auth_V1_LogoutRequest, options: CallOptions) async throws -> Auth_V1_LogoutResponse {
        try await logout(request: request, metadata: Metadata(), options: options)
    }
}

// MARK: - AuthGRPCClient

@available(iOS 18.0, *)
public final class AuthGRPCClient: AuthGRPCClientProtocol {

    // The generated Client<Transport> works with any ClientTransport.
    // We pin the concrete type to avoid existential boxing.
    private let client: Auth_V1_AuthService.Client<HTTP2ClientTransport.Posix>

    public init(grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client) {
        self.client = Auth_V1_AuthService.Client(wrapping: grpcClient)
    }

    // MARK: - Signup

    public func initiateSignup(
        request: Auth_V1_SignupRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_SignupResponse {
        do {
            return try await client.initiateSignup(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func verifySignupOTPs(
        request: Auth_V1_VerifyOTPsRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_VerifyOTPsResponse {
        do {
            return try await client.verifySignupOTPs(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    // MARK: - Login

    public func loginPrimary(
        request: Auth_V1_LoginRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_LoginPrimaryResponse {
        do {
            return try await client.loginPrimary(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func selectLoginMFAFactor(
        request: Auth_V1_SelectLoginMFAFactorRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_SelectLoginMFAFactorResponse {
        do {
            return try await client.selectLoginMFAFactor(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func verifyLoginMFA(
        request: Auth_V1_VerifyLoginMFARequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_AuthTokens {
        do {
            return try await client.verifyLoginMFA(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    // MARK: - TOTP

    public func setupTOTP(
        request: Auth_V1_SetupTOTPRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_SetupTOTPResponse {
        do {
            return try await client.setupTOTP(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func verifyTOTPSetup(
        request: Auth_V1_VerifyTOTPSetupRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_AuthTokens {
        do {
            return try await client.verifyTOTPSetup(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    // MARK: - Passkeys

    public func beginWebAuthnRegistration(
        request: Auth_V1_WebAuthnRegRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_WebAuthnRegResponse {
        do {
            return try await client.beginWebAuthnRegistration(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func finishWebAuthnRegistration(
        request: Auth_V1_WebAuthnFinishRegRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_AuthTokens {
        do {
            return try await client.finishWebAuthnRegistration(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func beginWebAuthnLogin(
        request: Auth_V1_WebAuthnLoginRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_WebAuthnLoginResponse {
        do {
            return try await client.beginWebAuthnLogin(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func finishWebAuthnLogin(
        request: Auth_V1_WebAuthnFinishLoginRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_AuthTokens {
        do {
            return try await client.finishWebAuthnLogin(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    // MARK: - Session

    public func refreshToken(
        request: Auth_V1_RefreshTokenRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_AuthTokens {
        do {
            return try await client.refreshToken(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }

    public func logout(
        request: Auth_V1_LogoutRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Auth_V1_LogoutResponse {
        do {
            return try await client.logout(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw AuthError.from(error) }
    }
}
