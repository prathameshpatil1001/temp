import Foundation

@available(iOS 18.0, *)
struct BranchAPI {
    func listBranches(limit: Int32 = 200, offset: Int32 = 0) async throws -> [Branch_V1_BankBranch] {
        let request: Branch_V1_ListBranchesRequest = {
            var req = Branch_V1_ListBranchesRequest()
            req.limit = limit
            req.offset = offset
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let branch = Branch_V1_BranchService.Client(wrapping: client)
                let response = try await branch.listBranches(request, metadata: await CoreAPIClient.authorizedMetadata())
                return response.branches
            }
        } catch {
            throw APIError.from(error)
        }
    }
}
