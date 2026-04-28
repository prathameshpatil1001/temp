import Foundation
import Combine
import GRPCNIOTransportHTTP2
import GRPCCore
import SwiftProtobuf
import GRPCProtobuf

final class BackendApplicationService: ApplicationServiceProtocol {
    private let tokenStore: TokenStore
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>

    init(
        tokenStore: TokenStore = .shared,
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client
    ) {
        self.tokenStore = tokenStore
        self.grpcClient = grpcClient
    }

    func fetchApplications() -> AnyPublisher<[LoanApplication], Error> {
        Future { promise in
            Task {
                do {
                    var req = Loan_ListLoanApplicationsRequest()
                    req.limit = 200; req.offset = 0; req.branchID = ""
                    let resp: Loan_ListLoanApplicationsResponse =
                        try await self.unaryLoanCall(method: "ListLoanApplications", request: req)
                    // Enrich with local metadata (name, phone) if available
                    let meta = LeadMetadataStore()
                    let apps: [LoanApplication] = resp.items
                        .filter { $0.status != .draft && $0.status != .unspecified && $0.status != .cancelled }
                        .map { app in
                            var a = self.map(app)
                            if let m = meta.metadata(for: app.id) {
                                a.name = m.name; a.phone = m.phone
                            }
                            return a
                        }
                    promise(.success(apps))
                } catch { promise(.failure(error)) }
            }
        }.eraseToAnyPublisher()
    }

    func updateStatus(id: UUID, status: ApplicationStatus) -> AnyPublisher<LoanApplication, Error> {
        // TODO: wire to UpdateLoanApplicationStatus when backend supports it from DST role
        Fail(error: URLError(.unsupportedURL)).eraseToAnyPublisher()
    }

    private func map(_ app: Loan_LoanApplication) -> LoanApplication {
        LoanApplication(
            id: UUID(uuidString: app.id) ?? UUID(),
            leadId: nil,
            name: app.primaryBorrowerProfileID,  // overwritten by metadata if available
            phone: "",
            loanType: mapLoanType(app.loanProductName),
            loanAmount: Double(app.requestedAmount) ?? 0,
            status: mapStatus(app.status),
            createdAt: ISO8601DateFormatter().date(from: app.createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: app.updatedAt) ?? Date(),
            slaDays: nil,
            statusLabel: mapStatusLabel(app.status),
            bankName: app.branchName,
            sanctionedAmount: nil, disbursedAmount: nil, rmName: nil
        )
    }

    private func mapStatus(_ s: Loan_LoanApplicationStatus) -> ApplicationStatus {
        switch s {
        case .submitted:                                         return .submitted
        case .approved, .officerApproved, .managerApproved:     return .approved
        case .rejected, .officerRejected, .managerRejected:     return .rejected
        case .disbursed:                                        return .disbursed
        default:                                                return .underReview
        }
    }
    private func mapStatusLabel(_ s: Loan_LoanApplicationStatus) -> String {
        switch s {
        case .submitted: return "Submitted"
        case .underReview, .officerReview, .managerReview: return "Under Review"
        case .approved, .officerApproved, .managerApproved: return "Sanctioned"
        case .rejected, .officerRejected, .managerRejected: return "Rejected"
        case .disbursed: return "Disbursed"
        default: return "Processing"
        }
    }
    private func mapLoanType(_ productName: String) -> LoanType {
        let name = productName.lowercased()
        if name.contains("home") { return .home }
        if name.contains("auto") || name.contains("vehicle") || name.contains("car") { return .auto }
        if name.contains("education") { return .education }
        if name.contains("business") { return .business }
        return .personal
    }

    private func unaryLoanCall<Request: SwiftProtobuf.Message, Response: SwiftProtobuf.Message>(
        method: String,
        request: Request
    ) async throws -> Response {
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw AuthError.unauthenticated
        }
        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let rpcRequest = ClientRequest<Request>(message: request, metadata: metadata)
        let response: ClientResponse<Response> = try await grpcClient.unary(
            request: rpcRequest,
            descriptor: MethodDescriptor(
                service: ServiceDescriptor(fullyQualifiedService: "loan.v1.LoanService"),
                method: method
            ),
            serializer: ProtobufSerializer<Request>(),
            deserializer: ProtobufDeserializer<Response>(),
            options: options,
            onResponse: { $0 }
        )
        return try response.message
    }
}
