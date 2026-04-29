// GRPCChannelFactory.swift
// lms_borrower/Networking
//
// Creates and manages the gRPC client connecting to the backend AuthService.
// Uses the `.http2NIOPosix` factory method from GRPCNIOTransportHTTP2 (grpc-swift v2).
//
// Architecture note:
// - This factory owns the GRPCClient lifecycle.
// - The underlying transport is HTTP/2 over TLS.
// - Certificate validation is ENABLED — never disable in production.

import GRPCCore
import GRPCNIOTransportHTTP2
import Foundation

// MARK: - GRPCChannelFactory

/// Provides a shared, lazily-started gRPC client for the current `AppEnvironment`.
///
/// ```swift
/// let factory = GRPCChannelFactory.shared
/// let authClient = Auth_V1_AuthService.Client(wrapping: factory.client)
/// ```
@available(iOS 18.0, *)
public final class GRPCChannelFactory: Sendable {

    // MARK: Singleton
    public static let shared = GRPCChannelFactory()

    // MARK: State
    public let client: GRPCClient<HTTP2ClientTransport.Posix>

    // MARK: Init
    public init(environment: AppEnvironment = .current) {
        let transport: HTTP2ClientTransport.Posix

        switch environment.tlsMode {
        case .tls:
            transport = try! HTTP2ClientTransport.Posix(
                target: .dns(host: environment.host, port: environment.port),
                transportSecurity: .tls
            )

        case .plaintext:
            #if DEBUG
            transport = try! HTTP2ClientTransport.Posix(
                target: .dns(host: environment.host, port: environment.port),
                transportSecurity: .plaintext
            )
            #else
            fatalError("GRPCChannelFactory: plaintext transport is not allowed in release builds.")
            #endif
        }

        self.client = GRPCClient(transport: transport)

        // Start the client event loop in the background.
        // GRPCClient.runConnections() drives the underlying connection; it must run
        // for the lifetime of the app. Errors here are fatal transport failures.
        Task {
            do {
                try await self.client.runConnections()
            } catch {
                // In production you'd log this via your logging framework.
                // Avoid printing sensitive data.
                print("[GRPCChannelFactory] Client exited: \(error)")
            }
        }
    }
}
