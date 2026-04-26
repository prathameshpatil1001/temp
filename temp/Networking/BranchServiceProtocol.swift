import Foundation

@available(iOS 18.0, *)
protocol BranchServiceProtocol {
    func listBranches(limit: Int, offset: Int) async throws -> [BorrowerBranch]
}
