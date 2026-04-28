import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(iOS 18.0, *)
enum CoreAPIClient {
    static func withClient<Result>(
        operation: @escaping @Sendable (GRPCClient<HTTP2ClientTransport.Posix>) async throws -> Result
    ) async throws -> Result {
        let transport = try HTTP2ClientTransport.Posix(
            target: .dns(host: APIConfig.host, port: APIConfig.port),
            transportSecurity: .tls
        )

        return try await withGRPCClient(transport: transport) { client in
            try await operation(client)
        }
    }

    static func authorizedMetadata() async -> Metadata {
        let token = await MainActor.run { SessionStore.shared.accessToken }
        var metadata: Metadata = [:]
        if !token.isEmpty {
            metadata.addString("Bearer \(token)", forKey: "authorization")
        }
        metadata.addString(UUID().uuidString, forKey: "x-request-id")
        return metadata
    }

    static func anonymousMetadata() -> Metadata {
        var metadata: Metadata = [:]
        metadata.addString(UUID().uuidString, forKey: "x-request-id")
        return metadata
    }

    static func withAuthorizedClient<Result>(
        operation: @escaping @Sendable (GRPCClient<HTTP2ClientTransport.Posix>, Metadata) async throws -> Result
    ) async throws -> Result {
        do {
            return try await withClient { client in
                let metadata = await authorizedMetadata()
                return try await operation(client, metadata)
            }
        } catch let rpcError as RPCError {
            guard rpcError.code == .unauthenticated else {
                throw rpcError
            }

            try await refreshAccessToken()

            return try await withClient { client in
                let metadata = await authorizedMetadata()
                return try await operation(client, metadata)
            }
        }
    }

    private static func refreshAccessToken() async throws {
        let (refreshToken, deviceID) = await MainActor.run {
            (SessionStore.shared.refreshToken, SessionStore.shared.deviceID)
        }

        guard !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.unauthenticated("Session expired. Please sign in again.")
        }

        var request = Auth_V1_RefreshTokenRequest()
        request.refreshToken = refreshToken
        request.deviceID = deviceID

        do {
            let tokens = try await withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.refreshToken(request, metadata: anonymousMetadata())
            }

            await MainActor.run {
                SessionStore.shared.updateTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            }
        } catch {
            await MainActor.run {
                SessionStore.shared.clear()
            }
            throw APIError.from(error)
        }
    }
}
