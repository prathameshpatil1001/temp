// AuthCallOptionsFactory.swift
// lms_borrower
//
// Centralises per-call gRPC options: timeout and bearer auth headers.
//
// gRPC-Swift v2 (GRPCCore) actual public API:
//   - CallOptions is created via CallOptions.defaults, then mutate properties.
//   - CallOptions has NO metadata field — auth headers go on ClientRequest.metadata.
//   - Metadata.addString(_:forKey:) is the correct public method (addValue is internal).
//   - Metadata supports dictionary literal: ["key": "value"] syntax.
//
// Rules enforced here:
//  - All calls get a standard timeout (prevents indefinite hangs).
//  - Protected calls provide a pre-built Metadata with the bearer token.
//  - Secrets are never logged or stored beyond the lifespan of these structs.

import GRPCCore
import Foundation

// MARK: - CallTimeout

/// Standard timeouts for different categories of gRPC call.
///
/// Auth flows are interactive (user is waiting), so timeouts are intentionally tight.
/// Do not make these values larger — a hung auth call should fail fast, not block the UI.
public enum CallTimeout {
    /// Standard interactive auth RPC (login, signup, OTP verify, TOTP).
    public static let authRPC: Duration = .seconds(15)

    /// Token refresh — must complete quickly to unblock in-flight protected requests.
    public static let tokenRefresh: Duration = .seconds(10)

    /// Logout — best-effort. The call is fired and the session is cleared regardless.
    public static let logout: Duration = .seconds(8)
}

// MARK: - AuthCallOptionsFactory

/// Builds `CallOptions` and request `Metadata` for each category of gRPC call.
///
/// ## Why two return values?
/// In grpc-swift 2, `CallOptions` holds per-call transport settings (timeout, retry, etc.)
/// but **does not carry metadata**. Auth headers must be placed on `ClientRequest.metadata`
/// at the call site. This factory provides helpers for both.
///
/// ## Usage
/// ```swift
/// // Unauthenticated call (e.g. InitiateSignup, LoginPrimary):
/// let options = AuthCallOptionsFactory.callOptions()
/// // In client:  try await client.initiateSignup(request, options: options)
///
/// // Authenticated call (e.g. SetupTOTP, Logout):
/// let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
/// let request = ClientRequest(message: myMessage, metadata: metadata)
/// try await client.setupTOTP(request, options: options)
/// ```
public enum AuthCallOptionsFactory {

    // MARK: CallOptions Builders

    /// Base call options with the given timeout. All other fields defer to transport defaults.
    public static func callOptions(timeout: Duration = CallTimeout.authRPC) -> CallOptions {
        var options = CallOptions.defaults
        options.timeout = timeout
        return options
    }

    /// Call options for unauthenticated RPCs (login, signup, OTP, MFA flows).
    public static func unauthenticated(
        timeout: Duration = CallTimeout.authRPC
    ) -> CallOptions {
        callOptions(timeout: timeout)
    }

    /// Call options specifically for token refresh calls.
    public static func forTokenRefresh() -> CallOptions {
        callOptions(timeout: CallTimeout.tokenRefresh)
    }

    /// Call options specifically for logout calls (shorter timeout, best-effort).
    public static func forLogout() -> CallOptions {
        callOptions(timeout: CallTimeout.logout)
    }

    // MARK: Auth Metadata Builder

    /// Builds the `Metadata` containing the Bearer authorization header.
    ///
    /// Attach this to your `ClientRequest` for protected RPCs:
    /// ```swift
    /// let metadata = AuthCallOptionsFactory.authMetadata(accessToken: token)
    /// let request  = ClientRequest(message: myMessage, metadata: metadata)
    /// ```
    ///
    /// - Parameter accessToken: A non-empty JWT access token from `TokenStore`.
    public static func authMetadata(accessToken: String) -> Metadata {
        precondition(
            !accessToken.isEmpty,
            "AuthCallOptionsFactory: access token must not be empty for authenticated calls."
        )
        var metadata = Metadata()
        metadata.addString("Bearer \(accessToken)", forKey: "authorization")
        return metadata
    }

    // MARK: Combined Helper

    /// Returns both `CallOptions` and initialised auth `Metadata` for protected RPCs.
    ///
    /// Convenience that avoids two separate calls in service layers.
    ///
    /// - Parameters:
    ///   - accessToken: The current JWT access token. Must not be empty.
    ///   - timeout: Call timeout. Defaults to the standard auth RPC timeout.
    /// - Returns: A tuple of `(CallOptions, Metadata)` ready to use at the call site.
    public static func authenticated(
        accessToken: String,
        timeout: Duration = CallTimeout.authRPC
    ) -> (options: CallOptions, metadata: Metadata) {
        (options: callOptions(timeout: timeout), metadata: authMetadata(accessToken: accessToken))
    }
}

// MARK: - CallOptions Extension

extension CallOptions {
    /// Returns a copy of these options with the given timeout applied.
    public func withTimeout(_ timeout: Duration) -> CallOptions {
        var copy = self
        copy.timeout = timeout
        return copy
    }
}
