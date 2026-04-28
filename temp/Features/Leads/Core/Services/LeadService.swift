import Foundation
import Combine
import GRPCCore
import GRPCProtobuf
import GRPCNIOTransportHTTP2
import SwiftProtobuf

// MARK: - Lead Service Protocol
// Swap MockLeadService with a real APILeadService without touching ViewModels
protocol LeadServiceProtocol {
    func fetchLeads() -> AnyPublisher<[Lead], Error>
    func addLead(_ lead: Lead) -> AnyPublisher<Lead, Error>
    func updateLead(_ lead: Lead) -> AnyPublisher<Lead, Error>
    func deleteLead(_ lead: Lead) -> AnyPublisher<Void, Error>
}

enum LeadDeletionError: LocalizedError {
    case onlySubmittedCanBeDeleted
    case backendDeleteUnavailable

    var errorDescription: String? {
        switch self {
        case .onlySubmittedCanBeDeleted:
            return "Only submitted leads can be deleted."
        case .backendDeleteUnavailable:
            return "Backend delete endpoint is not available for leads yet."
        }
    }
}

// MARK: - Backend Service
final class BackendLeadService: LeadServiceProtocol {
    private let tokenStore: TokenStore
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>
    private let leadMetadataStore = LeadMetadataStore()
    private let deletedLeadStore = DeletedLeadStore()

    init(
        tokenStore: TokenStore = .shared,
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client
    ) {
        self.tokenStore = tokenStore
        self.grpcClient = grpcClient
    }

    func fetchLeads() -> AnyPublisher<[Lead], Error> {
        Future { promise in
            Task {
                do {
                    // Fetch all applications from the backend.
                    // We show DRAFT (new), UNDER_REVIEW (docsPending) and SUBMITTED leads.
                    // Cancelled and already-actioned apps are excluded.
                    let apps = try await self.listLoanApplications()
                    let leads = apps
                        .filter { app in
                            guard app.status != .cancelled,
                                  !self.deletedLeadStore.contains(applicationID: app.id)
                            else { return false }
                            return true
                        }
                        .compactMap { self.mapLoanApplicationToLead($0) }
                        .sorted { $0.createdAt > $1.createdAt }
                    promise(.success(leads))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func addLead(_ lead: Lead) -> AnyPublisher<Lead, Error> {
        Future { promise in
            Task {
                do {
                    guard let borrowerProfileID = lead.borrowerProfileID, !borrowerProfileID.isEmpty else {
                        throw LeadAPIError.missingBorrowerProfile
                    }

                    // Use the product ID set at lead-creation time if available;
                    // fall back to auto-select by loan type for backward compatibility.
                    let resolvedProductID: String
                    if let pid = lead.loanProductID, !pid.isEmpty {
                        resolvedProductID = pid
                    } else {
                        let products = try await self.listLoanProducts()
                        guard let product = self.selectProduct(for: lead.loanType, products: products) else {
                            throw LeadAPIError.missingLoanProduct
                        }
                        resolvedProductID = product.id
                    }
                    let branchID = try await self.getDstBranchID()

                    // Create as DRAFT — this is the "lead" stage
                    let created = try await self.createLoanApplication(
                        borrowerProfileID: borrowerProfileID,
                        productID: resolvedProductID,
                        branchID: branchID,
                        amount: lead.loanAmount,
                        tenureMonths: Int32(lead.loanType.defaultTenureMonths),
                        status: .draft
                    )

                    // Persist UI metadata (name/phone/email/productID) keyed by applicationID
                    self.leadMetadataStore.save(
                        applicationID: created.id,
                        name: lead.name,
                        phone: lead.phone,
                        email: lead.email,
                        loanProductID: lead.loanProductID
                    )

                    guard var mapped = self.mapLoanApplicationToLead(created) else {
                        throw LeadAPIError.invalidResponse
                    }
                    // Preserve contact info from input (metadata store may not have flushed yet)
                    mapped.name = lead.name
                    mapped.phone = lead.phone
                    mapped.email = lead.email

                    promise(.success(mapped))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func updateLead(_ lead: Lead) -> AnyPublisher<Lead, Error> {
        // All leads are now backend-driven; every update is a status change on the backend.
        guard let applicationID = lead.applicationID, !applicationID.isEmpty else {
            // No applicationID means something went wrong during addLead — treat as a no-op.
            return Fail(error: LeadAPIError.missingBorrowerProfile).eraseToAnyPublisher()
        }

        return Future { promise in
            Task {
                do {
                    let backendStatus = self.mapLoanApplicationStatus(from: lead.status)
                    try await self.updateLoanApplicationStatus(applicationID: applicationID, status: backendStatus)
                    promise(.success(lead))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func deleteLead(_ lead: Lead) -> AnyPublisher<Void, Error> {
        // All leads are backend applications; cancel them regardless of status
        // (DRAFT leads can be cancelled just as SUBMITTED ones can).
        let applicationID = lead.applicationID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !applicationID.isEmpty else {
            // No application ID — nothing to cancel on the backend.
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return Future { promise in
            Task {
                do {
                    try await self.cancelLoanApplication(applicationID: applicationID)
                    self.leadMetadataStore.remove(applicationID: applicationID)
                    self.deletedLeadStore.save(applicationID: applicationID)
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func listLoanProducts() async throws -> [Loan_LoanProductItem] {
        var request = Loan_ListLoanProductsRequest()
        request.limit = 100
        request.offset = 0
        request.includeDeleted = false
        let response: Loan_ListLoanProductsResponse = try await unaryLoanCall(
            method: "ListLoanProducts",
            request: request
        )
        return response.items.filter { $0.isActive && !$0.isDeleted }
    }

    private func createLoanApplication(
        borrowerProfileID: String,
        productID: String,
        branchID: String,
        amount: Double,
        tenureMonths: Int32,
        status: Loan_LoanApplicationStatus = .draft
    ) async throws -> Loan_LoanApplication {
        var request = Loan_CreateLoanApplicationRequest()
        request.primaryBorrowerProfileID = borrowerProfileID
        request.loanProductID = productID
        request.branchID = branchID
        request.requestedAmount = String(Int(amount))
        request.tenureMonths = tenureMonths
        request.status = status
        let response: Loan_CreateLoanApplicationResponse = try await unaryLoanCall(
            method: "CreateLoanApplication",
            request: request
        )
        guard let application = response.application else {
            throw LeadAPIError.invalidResponse
        }
        return application
    }

    private func listLoanApplications() async throws -> [Loan_LoanApplication] {
        var request = Loan_ListLoanApplicationsRequest()
        request.limit = 200
        request.offset = 0
        request.branchID = ""
        let response: Loan_ListLoanApplicationsResponse = try await unaryLoanCall(
            method: "ListLoanApplications",
            request: request
        )
        return response.items
    }

    private func cancelLoanApplication(applicationID: String) async throws {
        try await self.updateLoanApplicationStatus(applicationID: applicationID, status: .cancelled)
    }

    private func updateLoanApplicationStatus(applicationID: String, status: Loan_LoanApplicationStatus) async throws {
        var request = Loan_UpdateLoanApplicationStatusRequest()
        request.applicationID = applicationID
        request.status = status
        request.escalationReason = ""
        _ = try await unaryLoanCall(
            method: "UpdateLoanApplicationStatus",
            request: request
        ) as Loan_UpdateLoanApplicationStatusResponse
    }

    private func getDstBranchID() async throws -> String {
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw AuthError.unauthenticated
        }

        let auth = Auth_V1_AuthService.Client(wrapping: grpcClient)
        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let request = Auth_V1_GetMyProfileRequest()
        let response = try await auth.getMyProfile(
            request: .init(message: request, metadata: metadata),
            options: options
        )

        if case .dstProfile(let dstProfile) = response.profile {
            let branchID = dstProfile.branch.branchID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !branchID.isEmpty { return branchID }
        }

        throw LeadAPIError.missingBranch
    }

    private func mapLoanApplicationStatus(from status: LeadStatus) -> Loan_LoanApplicationStatus {
        switch status {
        case .new:         return .draft
        case .docsPending: return .underReview
        case .submitted:   return .submitted
        case .rejected:    return .rejected
        case .approved:    return .approved
        case .disbursed:   return .disbursed
        }
    }

    private func selectProduct(for loanType: LoanType, products: [Loan_LoanProductItem]) -> Loan_LoanProductItem? {
        let category: Loan_LoanProductCategory
        switch loanType {
        case .personal:
            category = .personal
        case .home:
            category = .home
        case .auto:
            category = .vehicle
        case .education:
            category = .education
        case .business:
            category = .personal
        }

        return products.first(where: { $0.category == category }) ?? products.first
    }

    private func mapLoanApplicationToLead(_ application: Loan_LoanApplication) -> Lead? {
        let id = application.id
        // DRAFT applications may have amount == 0 if the DST sets it later; allow them through.
        let amount = Double(application.requestedAmount) ?? 0

        let createdAt = ISO8601DateFormatter().date(from: application.createdAt) ?? Date()
        let updatedAt = ISO8601DateFormatter().date(from: application.updatedAt) ?? createdAt
        let cached = leadMetadataStore.metadata(for: application.id)

        return Lead(
            id: id,
            applicationID: application.id,
            name: cached?.name ?? "Borrower \(application.primaryBorrowerProfileID.prefix(6))",
            phone: cached?.phone ?? "",
            email: cached?.email ?? "",
            borrowerProfileID: application.primaryBorrowerProfileID,
            loanType: mapLoanTypeFromProductName(application.loanProductName),
            loanProductID: cached?.loanProductID,   // saved when lead was created
            loanAmount: amount,
            status: mapLeadStatus(application.status),
            createdAt: createdAt,
            updatedAt: updatedAt,
            assignedRM: nil,
            branchCode: application.branchName
        )
    }

    private func mapLoanTypeFromProductName(_ name: String) -> LoanType {
        let lower = name.lowercased()
        if lower.contains("home") { return .home }
        if lower.contains("car") || lower.contains("vehicle") || lower.contains("auto") { return .auto }
        if lower.contains("education") { return .education }
        if lower.contains("business") { return .business }
        return .personal
    }

    private func mapLeadStatus(_ status: Loan_LoanApplicationStatus) -> LeadStatus {
        switch status {
        case .submitted:
            return .submitted
        case .approved, .managerApproved, .officerApproved:
            return .approved
        case .rejected, .managerRejected, .officerRejected:
            return .rejected
        case .disbursed:
            return .disbursed
        case .underReview, .managerReview, .officerReview:
            return .docsPending
        case .draft:
            return .new
        default:
            return .new
        }
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

enum LeadAPIError: LocalizedError {
    case missingBorrowerProfile
    case missingBranch
    case missingLoanProduct
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingBorrowerProfile:
            return "Borrower profile ID is required to create the lead."
        case .missingBranch:
            return "DST branch is missing in profile."
        case .missingLoanProduct:
            return "No active loan product available for this lead type."
        case .invalidResponse:
            return "Backend returned an invalid lead response."
        }
    }
}

// MARK: - Mock Service
final class MockLeadService: LeadServiceProtocol {
    static let shared = MockLeadService()
    private var store: [Lead] = []

    private init() {
        if store.isEmpty {
             let initials: [Lead] = [
                Lead(id: UUID().uuidString, name: "Arjun Mehta",   phone: "9876543210", email: "arjun@email.com",   loanType: .home,      loanAmount: 3_500_000, status: .new,         createdAt: Date().addingTimeInterval(-7200),  updatedAt: Date(), assignedRM: "Priya S", branchCode: "MYS01"),
                Lead(id: UUID().uuidString, name: "Priya Sharma",  phone: "9845001234", email: "priya@email.com",   loanType: .personal,  loanAmount:   800_000, status: .docsPending, createdAt: Date().addingTimeInterval(-86400), updatedAt: Date(), assignedRM: nil,       branchCode: "MYS01"),
                Lead(id: UUID().uuidString, name: "Rohit Verma",   phone: "9900112233", email: "rohit@email.com",   loanType: .business,  loanAmount: 5_000_000, status: .submitted,   createdAt: Date().addingTimeInterval(-172800),updatedAt: Date(), assignedRM: "Priya S", branchCode: "MYS02"),
                Lead(id: UUID().uuidString, name: "Kavitha Nair",  phone: "9844556677", email: "kavitha@email.com", loanType: .home,      loanAmount: 6_000_000, status: .rejected,    createdAt: Date().addingTimeInterval(-259200),updatedAt: Date(), assignedRM: "Vikram R", branchCode: "MYS01"),
                Lead(id: UUID().uuidString, name: "Siddharth Rao", phone: "7760001234", email: "sid@email.com",     loanType: .auto,      loanAmount: 1_200_000, status: .new,         createdAt: Date().addingTimeInterval(-3600),  updatedAt: Date(), assignedRM: nil,        branchCode: "MYS03"),
                Lead(id: UUID().uuidString, name: "Meera Patel",   phone: "9741236547", email: "meera@email.com",   loanType: .personal,  loanAmount:   500_000, status: .docsPending, createdAt: Date().addingTimeInterval(-14400), updatedAt: Date(), assignedRM: "Priya S",  branchCode: "MYS01"),
                Lead(id: UUID().uuidString, name: "Kiran Hegde",   phone: "9632147852", email: "kiran@email.com",   loanType: .education, loanAmount: 1_500_000, status: .approved,    createdAt: Date().addingTimeInterval(-432000),updatedAt: Date(), assignedRM: "Vikram R", branchCode: "MYS02"),
                Lead(id: UUID().uuidString, name: "Deepa Nanda",   phone: "8867452130", email: "deepa@email.com",   loanType: .home,      loanAmount: 4_200_000, status: .disbursed,   createdAt: Date().addingTimeInterval(-604800),updatedAt: Date(), assignedRM: "Priya S",  branchCode: "MYS01"),
            ]
            store.append(contentsOf: initials)
        }
    }

    func fetchLeads() -> AnyPublisher<[Lead], Error> {
        Just(store)
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func addLead(_ lead: Lead) -> AnyPublisher<Lead, Error> {
        store.append(lead)
        return Just(lead)
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateLead(_ lead: Lead) -> AnyPublisher<Lead, Error> {
        if let idx = store.firstIndex(where: { $0.id == lead.id }) {
            store[idx] = lead
        }
        return Just(lead)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func deleteLead(_ lead: Lead) -> AnyPublisher<Void, Error> {
        store.removeAll { $0.id == lead.id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Minimal Loan Protobuf Models (for DirectSalesTeamApp)
enum Loan_LoanProductCategory: SwiftProtobuf.Enum, Sendable {
    typealias RawValue = Int
    case unspecified
    case personal
    case home
    case vehicle
    case education
    case UNRECOGNIZED(Int)

    init() { self = .unspecified }
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .personal
        case 2: self = .home
        case 3: self = .vehicle
        case 4: self = .education
        default: self = .UNRECOGNIZED(rawValue)
        }
    }
    var rawValue: Int {
        switch self {
        case .unspecified: return 0
        case .personal: return 1
        case .home: return 2
        case .vehicle: return 3
        case .education: return 4
        case .UNRECOGNIZED(let v): return v
        }
    }
}

enum Loan_LoanApplicationStatus: SwiftProtobuf.Enum, Sendable {
    typealias RawValue = Int
    case unspecified, draft, submitted, underReview, approved, rejected, disbursed, cancelled
    case officerReview, officerApproved, officerRejected, managerReview, managerApproved, managerRejected
    case UNRECOGNIZED(Int)

    init() { self = .unspecified }
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .draft
        case 2: self = .submitted
        case 3: self = .underReview
        case 4: self = .approved
        case 5: self = .rejected
        case 6: self = .disbursed
        case 7: self = .cancelled
        case 8: self = .officerReview
        case 9: self = .officerApproved
        case 10: self = .officerRejected
        case 11: self = .managerReview
        case 12: self = .managerApproved
        case 13: self = .managerRejected
        default: self = .UNRECOGNIZED(rawValue)
        }
    }
    var rawValue: Int {
        switch self {
        case .unspecified: return 0
        case .draft: return 1
        case .submitted: return 2
        case .underReview: return 3
        case .approved: return 4
        case .rejected: return 5
        case .disbursed: return 6
        case .cancelled: return 7
        case .officerReview: return 8
        case .officerApproved: return 9
        case .officerRejected: return 10
        case .managerReview: return 11
        case .managerApproved: return 12
        case .managerRejected: return 13
        case .UNRECOGNIZED(let v): return v
        }
    }
}

struct Loan_LoanProductItem: Sendable {
    var id: String = ""
    var name: String = ""
    var category: Loan_LoanProductCategory = .unspecified
    var isActive: Bool = false
    var isDeleted: Bool = false
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_ListLoanProductsRequest: Sendable {
    var limit: Int32 = 0
    var offset: Int32 = 0
    var includeDeleted: Bool = false
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_ListLoanProductsResponse: Sendable {
    var items: [Loan_LoanProductItem] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_LoanApplication: Sendable {
    var id: String = ""
    var primaryBorrowerProfileID: String = ""
    var loanProductName: String = ""
    var branchName: String = ""
    var requestedAmount: String = ""
    var status: Loan_LoanApplicationStatus = .unspecified
    var createdAt: String = ""
    var updatedAt: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_CreateLoanApplicationRequest: Sendable {
    var primaryBorrowerProfileID: String = ""
    var loanProductID: String = ""
    var branchID: String = ""
    var requestedAmount: String = ""
    var tenureMonths: Int32 = 0
    var status: Loan_LoanApplicationStatus = .unspecified
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_CreateLoanApplicationResponse: Sendable {
    var application: Loan_LoanApplication?
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_ListLoanApplicationsRequest: Sendable {
    var limit: Int32 = 0
    var offset: Int32 = 0
    var branchID: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_ListLoanApplicationsResponse: Sendable {
    var items: [Loan_LoanApplication] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_UpdateLoanApplicationStatusRequest: Sendable {
    var applicationID: String = ""
    var status: Loan_LoanApplicationStatus = .unspecified
    var escalationReason: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

struct Loan_UpdateLoanApplicationStatusResponse: Sendable {
    var success: Bool = false
    var unknownFields = SwiftProtobuf.UnknownStorage()
}

extension Loan_LoanProductItem: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.LoanProduct"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &id)
            case 2: try decoder.decodeSingularStringField(value: &name)
            case 3: try decoder.decodeSingularEnumField(value: &category)
            case 9: try decoder.decodeSingularBoolField(value: &isActive)
            case 10: try decoder.decodeSingularBoolField(value: &isDeleted)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !id.isEmpty { try visitor.visitSingularStringField(value: id, fieldNumber: 1) }
        if !name.isEmpty { try visitor.visitSingularStringField(value: name, fieldNumber: 2) }
        if category != .unspecified { try visitor.visitSingularEnumField(value: category, fieldNumber: 3) }
        if isActive { try visitor.visitSingularBoolField(value: isActive, fieldNumber: 9) }
        if isDeleted { try visitor.visitSingularBoolField(value: isDeleted, fieldNumber: 10) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_ListLoanProductsRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.ListLoanProductsRequest"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularInt32Field(value: &limit)
            case 2: try decoder.decodeSingularInt32Field(value: &offset)
            case 3: try decoder.decodeSingularBoolField(value: &includeDeleted)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if limit != 0 { try visitor.visitSingularInt32Field(value: limit, fieldNumber: 1) }
        if offset != 0 { try visitor.visitSingularInt32Field(value: offset, fieldNumber: 2) }
        if includeDeleted { try visitor.visitSingularBoolField(value: includeDeleted, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_ListLoanProductsResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.ListLoanProductsResponse"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeRepeatedMessageField(value: &items)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !items.isEmpty { try visitor.visitRepeatedMessageField(value: items, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_LoanApplication: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.LoanApplication"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &id)
            case 3: try decoder.decodeSingularStringField(value: &primaryBorrowerProfileID)
            case 5: try decoder.decodeSingularStringField(value: &loanProductName)
            case 7: try decoder.decodeSingularStringField(value: &branchName)
            case 8: try decoder.decodeSingularStringField(value: &requestedAmount)
            case 10: try decoder.decodeSingularEnumField(value: &status)
            case 16: try decoder.decodeSingularStringField(value: &createdAt)
            case 17: try decoder.decodeSingularStringField(value: &updatedAt)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !id.isEmpty { try visitor.visitSingularStringField(value: id, fieldNumber: 1) }
        if !primaryBorrowerProfileID.isEmpty { try visitor.visitSingularStringField(value: primaryBorrowerProfileID, fieldNumber: 3) }
        if !loanProductName.isEmpty { try visitor.visitSingularStringField(value: loanProductName, fieldNumber: 5) }
        if !branchName.isEmpty { try visitor.visitSingularStringField(value: branchName, fieldNumber: 7) }
        if !requestedAmount.isEmpty { try visitor.visitSingularStringField(value: requestedAmount, fieldNumber: 8) }
        if status != .unspecified { try visitor.visitSingularEnumField(value: status, fieldNumber: 10) }
        if !createdAt.isEmpty { try visitor.visitSingularStringField(value: createdAt, fieldNumber: 16) }
        if !updatedAt.isEmpty { try visitor.visitSingularStringField(value: updatedAt, fieldNumber: 17) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_CreateLoanApplicationRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.CreateLoanApplicationRequest"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &primaryBorrowerProfileID)
            case 2: try decoder.decodeSingularStringField(value: &loanProductID)
            case 3: try decoder.decodeSingularStringField(value: &branchID)
            case 4: try decoder.decodeSingularStringField(value: &requestedAmount)
            case 5: try decoder.decodeSingularInt32Field(value: &tenureMonths)
            case 6: try decoder.decodeSingularEnumField(value: &status)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !primaryBorrowerProfileID.isEmpty { try visitor.visitSingularStringField(value: primaryBorrowerProfileID, fieldNumber: 1) }
        if !loanProductID.isEmpty { try visitor.visitSingularStringField(value: loanProductID, fieldNumber: 2) }
        if !branchID.isEmpty { try visitor.visitSingularStringField(value: branchID, fieldNumber: 3) }
        if !requestedAmount.isEmpty { try visitor.visitSingularStringField(value: requestedAmount, fieldNumber: 4) }
        if tenureMonths != 0 { try visitor.visitSingularInt32Field(value: tenureMonths, fieldNumber: 5) }
        if status != .unspecified { try visitor.visitSingularEnumField(value: status, fieldNumber: 6) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_CreateLoanApplicationResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.CreateLoanApplicationResponse"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1:
                var value: Loan_LoanApplication?
                if case .some(let current) = application { value = current }
                try decoder.decodeSingularMessageField(value: &value)
                application = value
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if let application {
            try visitor.visitSingularMessageField(value: application, fieldNumber: 1)
        }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_ListLoanApplicationsRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.ListLoanApplicationsRequest"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularInt32Field(value: &limit)
            case 2: try decoder.decodeSingularInt32Field(value: &offset)
            case 3: try decoder.decodeSingularStringField(value: &branchID)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if limit != 0 { try visitor.visitSingularInt32Field(value: limit, fieldNumber: 1) }
        if offset != 0 { try visitor.visitSingularInt32Field(value: offset, fieldNumber: 2) }
        if !branchID.isEmpty { try visitor.visitSingularStringField(value: branchID, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_ListLoanApplicationsResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.ListLoanApplicationsResponse"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeRepeatedMessageField(value: &items)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !items.isEmpty { try visitor.visitRepeatedMessageField(value: items, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_UpdateLoanApplicationStatusRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.UpdateLoanApplicationStatusRequest"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &applicationID)
            case 2: try decoder.decodeSingularEnumField(value: &status)
            case 3: try decoder.decodeSingularStringField(value: &escalationReason)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !applicationID.isEmpty { try visitor.visitSingularStringField(value: applicationID, fieldNumber: 1) }
        if status != .unspecified { try visitor.visitSingularEnumField(value: status, fieldNumber: 2) }
        if !escalationReason.isEmpty { try visitor.visitSingularStringField(value: escalationReason, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

extension Loan_UpdateLoanApplicationStatusResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "loan.v1.UpdateLoanApplicationStatusResponse"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularBoolField(value: &success)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if success { try visitor.visitSingularBoolField(value: success, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
}

struct StoredLeadMetadata: Codable {
    let name: String
    let phone: String
    let email: String
    var loanProductID: String?   // product chosen at lead-creation time
}

final class LeadMetadataStore {
    private let key = "dst.lead.metadata.byApplicationID"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func metadata(for applicationID: String) -> StoredLeadMetadata? {
        guard !applicationID.isEmpty else { return nil }
        return all()[applicationID]
    }

    func save(applicationID: String, name: String, phone: String, email: String, loanProductID: String? = nil) {
        guard !applicationID.isEmpty else { return }
        var existing = all()
        existing[applicationID] = StoredLeadMetadata(name: name, phone: phone, email: email, loanProductID: loanProductID)
        persist(existing)
    }

    func remove(applicationID: String) {
        guard !applicationID.isEmpty else { return }
        var existing = all()
        existing.removeValue(forKey: applicationID)
        persist(existing)
    }

    private func all() -> [String: StoredLeadMetadata] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: StoredLeadMetadata].self, from: data)) ?? [:]
    }

    private func persist(_ value: [String: StoredLeadMetadata]) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}

private final class DeletedLeadStore {
    private let key = "dst.deleted.application.ids"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func contains(applicationID: String) -> Bool {
        guard !applicationID.isEmpty else { return false }
        return all().contains(applicationID)
    }

    func save(applicationID: String) {
        guard !applicationID.isEmpty else { return }
        var ids = all()
        ids.insert(applicationID)
        persist(ids)
    }

    func remove(applicationID: String) {
        guard !applicationID.isEmpty else { return }
        var ids = all()
        ids.remove(applicationID)
        persist(ids)
    }

    private func all() -> Set<String> {
        let ids = defaults.stringArray(forKey: key) ?? []
        return Set(ids)
    }

    private func persist(_ value: Set<String>) {
        defaults.set(Array(value), forKey: key)
    }
}

