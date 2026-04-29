import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

enum BranchError: Error, LocalizedError {
    case unauthenticated
    case networkError(String)
    case underlyingError(RPCError)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Session expired. Please log in again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .underlyingError(let error):
            return error.message
        }
    }

    static func from(_ error: Error) -> BranchError {
        guard let rpc = error as? RPCError else {
            return .networkError(error.localizedDescription)
        }
        if rpc.code == .unauthenticated {
            return .unauthenticated
        }
        return .underlyingError(rpc)
    }
}

@available(iOS 18.0, *)
final class BranchGRPCClient: BranchServiceProtocol {
    private let client: Branch_V1_BranchService.Client<HTTP2ClientTransport.Posix>
    private let tokenStore: TokenStore

    init(
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client,
        tokenStore: TokenStore = .shared
    ) {
        self.client = Branch_V1_BranchService.Client(wrapping: grpcClient)
        self.tokenStore = tokenStore
    }

    private func authContext() throws -> (options: CallOptions, metadata: Metadata) {
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw BranchError.unauthenticated
        }
        return AuthCallOptionsFactory.authenticated(accessToken: token)
    }

    func listBranches(limit: Int, offset: Int) async throws -> [BorrowerBranch] {
        var request = Branch_V1_ListBranchesRequest()
        request.limit = Int32(limit)
        request.offset = Int32(offset)

        do {
            let (options, metadata) = try authContext()
            let response = try await client.listBranches(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return response.branches.map {
                BorrowerBranch(
                    id: $0.id,
                    name: $0.name,
                    region: $0.region,
                    city: $0.city
                )
            }
        } catch {
            throw BranchError.from(error)
        }
    }
}
