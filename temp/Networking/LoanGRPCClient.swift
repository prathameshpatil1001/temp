import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

enum LoanError: Error, LocalizedError {
    case unauthenticated
    case notFound(String)
    case permissionDenied(String)
    case invalidInput(String)
    case preconditionFailed(String)
    case networkError(String)
    case underlyingError(RPCError)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Session expired. Please log in again."
        case .notFound(let message):
            return "Not found: \(message)"
        case .permissionDenied(let message):
            return "Access denied: \(message)"
        case .invalidInput(let message):
            return message
        case .preconditionFailed(let message):
            return message
        case .networkError(let message):
            return "Network error: \(message)"
        case .underlyingError(let error):
            return error.message
        case .unknown:
            return "An unknown error occurred."
        }
    }

    static func from(_ error: Error) -> LoanError {
        guard let rpc = error as? RPCError else {
            return .networkError(error.localizedDescription)
        }

        switch rpc.code {
        case .unauthenticated:
            return .unauthenticated
        case .notFound:
            return .notFound(rpc.message)
        case .permissionDenied:
            return .permissionDenied(rpc.message)
        case .invalidArgument:
            return .invalidInput(rpc.message)
        case .failedPrecondition:
            return .preconditionFailed(rpc.message)
        case .unavailable, .deadlineExceeded:
            return .networkError(rpc.message)
        default:
            return .underlyingError(rpc)
        }
    }
}

@available(iOS 18.0, *)
final class LoanGRPCClient: LoanServiceProtocol {
    private let client: Loan_V1_LoanService.Client<HTTP2ClientTransport.Posix>
    private let tokenStore: TokenStore

    init(
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client,
        tokenStore: TokenStore = .shared
    ) {
        self.client = Loan_V1_LoanService.Client(wrapping: grpcClient)
        self.tokenStore = tokenStore
    }

    private func authContext() throws -> (options: CallOptions, metadata: Metadata) {
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw LoanError.unauthenticated
        }
        return AuthCallOptionsFactory.authenticated(accessToken: token)
    }

    func listLoanProducts(limit: Int, offset: Int) async throws -> [LoanProduct] {
        var request = Loan_V1_ListLoanProductsRequest()
        request.limit = Int32(limit)
        request.offset = Int32(offset)
        request.includeDeleted = false

        do {
            let (options, metadata) = try authContext()
            let response = try await client.listLoanProducts(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return response.items.map(LoanProduct.from(proto:))
        } catch {
            throw LoanError.from(error)
        }
    }

    func getLoanProduct(productId: String) async throws -> LoanProduct {
        var request = Loan_V1_GetLoanProductRequest()
        request.productID = productId

        do {
            let (options, metadata) = try authContext()
            let response = try await client.getLoanProduct(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return LoanProduct.from(proto: response.product)
        } catch {
            throw LoanError.from(error)
        }
    }

    func createLoanApplication(
        primaryBorrowerProfileId: String,
        loanProductId: String,
        branchId: String,
        requestedAmount: String,
        tenureMonths: Int
    ) async throws -> BorrowerLoanApplication {
        var request = Loan_V1_CreateLoanApplicationRequest()
        request.primaryBorrowerProfileID = primaryBorrowerProfileId
        request.loanProductID = loanProductId
        request.branchID = branchId
        request.requestedAmount = requestedAmount
        request.tenureMonths = Int32(tenureMonths)
        request.status = .submitted

        do {
            let (options, metadata) = try authContext()
            let response = try await client.createLoanApplication(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return BorrowerLoanApplication.from(proto: response.application)
        } catch {
            throw LoanError.from(error)
        }
    }

    func getLoanApplication(applicationId: String) async throws -> BorrowerLoanApplication {
        var request = Loan_V1_GetLoanApplicationRequest()
        request.applicationID = applicationId

        do {
            let (options, metadata) = try authContext()
            let response = try await client.getLoanApplication(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return BorrowerLoanApplication.from(detailResponse: response)
        } catch {
            throw LoanError.from(error)
        }
    }

    func listLoanApplications(limit: Int, offset: Int) async throws -> [BorrowerLoanApplication] {
        var request = Loan_V1_ListLoanApplicationsRequest()
        request.limit = Int32(limit)
        request.offset = Int32(offset)

        do {
            let (options, metadata) = try authContext()
            let response = try await client.listLoanApplications(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return response.items.map(BorrowerLoanApplication.from(proto:))
        } catch {
            throw LoanError.from(error)
        }
    }

    func addApplicationDocument(
        applicationId: String,
        borrowerProfileId: String,
        requiredDocId: String,
        mediaFileId: String
    ) async throws -> BorrowerApplicationDocument {
        var request = Loan_V1_AddApplicationDocumentRequest()
        request.applicationID = applicationId
        request.borrowerProfileID = borrowerProfileId
        request.requiredDocID = requiredDocId
        request.mediaFileID = mediaFileId
        request.verificationStatus = .pending

        do {
            let (options, metadata) = try authContext()
            let response = try await client.addApplicationDocument(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return BorrowerApplicationDocument.from(proto: response.document)
        } catch {
            throw LoanError.from(error)
        }
    }

    func getLoan(loanId: String?, applicationId: String?) async throws -> ActiveLoan {
        var request = Loan_V1_GetLoanRequest()
        if let loanId {
            request.loanID = loanId
        }
        if let applicationId {
            request.applicationID = applicationId
        }

        do {
            let (options, metadata) = try authContext()
            let response = try await client.getLoan(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return ActiveLoan.from(proto: response.loan)
        } catch {
            throw LoanError.from(error)
        }
    }

    func listLoans(limit: Int, offset: Int) async throws -> [ActiveLoan] {
        var request = Loan_V1_ListLoansRequest()
        request.limit = Int32(limit)
        request.offset = Int32(offset)

        do {
            let (options, metadata) = try authContext()
            let response = try await client.listLoans(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return response.items.map(ActiveLoan.from(proto:))
        } catch {
            throw LoanError.from(error)
        }
    }

    func listEmiSchedule(loanId: String) async throws -> [EmiScheduleItem] {
        var request = Loan_V1_ListEmiScheduleRequest()
        request.loanID = loanId

        do {
            let (options, metadata) = try authContext()
            let response = try await client.listEmiSchedule(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return response.items.map(EmiScheduleItem.from(proto:))
        } catch {
            throw LoanError.from(error)
        }
    }

    func listPayments(loanId: String) async throws -> [LoanPayment] {
        var request = Loan_V1_ListPaymentsRequest()
        request.loanID = loanId

        do {
            let (options, metadata) = try authContext()
            let response = try await client.listPayments(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return response.items.map(LoanPayment.from(proto:))
        } catch {
            throw LoanError.from(error)
        }
    }

    func recordPayment(
        loanId: String,
        emiScheduleId: String,
        amount: String,
        externalTransactionId: String
    ) async throws -> LoanPayment {
        var request = Loan_V1_RecordPaymentRequest()
        request.loanID = loanId
        request.emiScheduleID = emiScheduleId
        request.amount = amount
        request.externalTransactionID = externalTransactionId
        request.status = .success

        do {
            let (options, metadata) = try authContext()
            let response = try await client.recordPayment(
                request: .init(message: request, metadata: metadata),
                options: options
            )
            return LoanPayment.from(proto: response.payment)
        } catch {
            throw LoanError.from(error)
        }
    }
}
