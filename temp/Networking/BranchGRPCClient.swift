import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

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
            throw LoanError.unauthenticated // We can reuse LoanError or generic error
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
            return response.branches.map { proto in
                BorrowerBranch(
                    id: proto.id,
                    name: proto.name,
                    region: proto.region,
                    city: proto.city
                )
            }
        } catch {
            throw LoanError.from(error) // Using LoanError for convenience
        }
    }
}
