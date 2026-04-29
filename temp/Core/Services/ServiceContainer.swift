@available(iOS 18.0, *)
enum ServiceContainer {
    static let loanService: LoanServiceProtocol = LoanGRPCClient()
    static let branchService: BranchServiceProtocol = BranchGRPCClient()
    static let chatService: ChatServiceProtocol = ChatService()
}
