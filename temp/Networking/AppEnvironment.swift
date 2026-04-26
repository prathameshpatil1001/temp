// AppEnvironment.swift
// lms_borrower
//
// Defines the runtime environment configuration for gRPC connections.
// All networking code reads from this single source of truth.
// Do NOT put credentials or secrets here — only host/port/TLS config.

import Foundation

// MARK: - TLS Mode

/// Controls how TLS is applied to the gRPC channel.
public enum GRPCTLSMode: Sendable {
    /// Full TLS with server certificate validation (use in production).
    case tls
    /// Plaintext — no TLS. Only valid for local development against a local server.
    case plaintext
}

// MARK: - AppEnvironment

/// Holds the gRPC endpoint configuration for the current build target.
///
/// Usage:
/// ```swift
/// let env = AppEnvironment.current
/// // env.host → "lmsapi.chirag.codes"
/// // env.port → 443
/// // env.tlsMode → .tls
/// ```
public struct AppEnvironment: Sendable {

    // MARK: Properties
    /// The gRPC server hostname (no scheme prefix).
    public let host: String

    /// The gRPC server port.
    /// - Production: 443 (TLS over HTTP/2)
    /// - Local dev:  50051 (plaintext)
    public let port: Int

    /// TLS mode applied to the channel. Must be `.tls` in production.
    public let tlsMode: GRPCTLSMode

    /// Human-readable name for this environment (used in logs only, never in requests).
    public let name: String

    // MARK: Derived

    /// Full address string for display/logging purposes only.
    /// Never use this to make network calls — use `host` and `port` separately.
    public var displayAddress: String {
        "\(host):\(port)"
    }

    // MARK: Known Environments

    /// Production backend at `lmsapi.chirag.codes:443` with TLS.
    public static let production = AppEnvironment(
        host: "lmsapi.chirag.codes",
        port: 443,
        tlsMode: .tls,
        name: "Production"
    )

    /// Local development server running on localhost:50051 without TLS.
    /// Only used when `DEBUG` is defined and the developer explicitly sets `.localDev`.
    public static let localDev = AppEnvironment(
        host: "localhost",
        port: 50051,
        tlsMode: .plaintext,
        name: "Local Dev"
    )

    // MARK: Current

    /// The active environment for this build.
    ///
    /// Switch to `.localDev` during development by changing this value.
    /// This should always be `.production` in release builds.
    public static let current: AppEnvironment = {
        #if DEBUG
        // Change to `.localDev` when running against a local backend.
        return .production
        #else
        return .production
        #endif
    }()
}
