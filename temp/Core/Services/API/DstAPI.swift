import Foundation

@available(iOS 18.0, *)
struct DstAPI {
    func listDstAccounts(branchID: String = "", limit: Int32 = 20, offset: Int32 = 0) async throws -> [Dst_V1_DstAccount] {
        let request: Dst_V1_ListDstAccountsRequest = {
            var req = Dst_V1_ListDstAccountsRequest()
            req.branchID = branchID
            req.limit = limit
            req.offset = offset
            return req
        }()

        do {
            let response: Dst_V1_ListDstAccountsResponse = try await CoreAPIClient.withClient { client in
                let dst = Dst_V1_DstService.Client(wrapping: client)
                return try await dst.listDstAccounts(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
            return response.items
        } catch {
            throw APIError.from(error)
        }
    }

    func getDstAccount(userID: String) async throws -> Dst_V1_DstAccount {
        let request: Dst_V1_GetDstAccountRequest = {
            var req = Dst_V1_GetDstAccountRequest()
            req.userID = userID
            return req
        }()

        do {
            let response: Dst_V1_GetDstAccountResponse = try await CoreAPIClient.withClient { client in
                let dst = Dst_V1_DstService.Client(wrapping: client)
                return try await dst.getDstAccount(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
            return response.account
        } catch {
            throw APIError.from(error)
        }
    }
}
