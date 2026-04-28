import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(iOS 18.0, *)
struct LoanAPI {
    func listLoanProducts(limit: Int32 = 100, offset: Int32 = 0, includeDeleted: Bool = false, authorized: Bool = true) async throws -> [Loan_V1_LoanProduct] {
        var request = Loan_V1_ListLoanProductsRequest()
        request.limit = limit
        request.offset = offset
        request.includeDeleted = includeDeleted

        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.listLoanProducts(req, metadata: metadata).items
        }
    }

    func getLoanProduct(productID: String, authorized: Bool = true) async throws -> Loan_V1_LoanProduct {
        var request = Loan_V1_GetLoanProductRequest()
        request.productID = productID
        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.getLoanProduct(req, metadata: metadata).product
        }
    }

    func createLoanProduct(_ product: LoanProduct) async throws -> Loan_V1_LoanProduct {
        try await perform(product.protoCreateRequest, authorized: true) { service, req, metadata in
            try await service.createLoanProduct(req, metadata: metadata).product
        }
    }

    func updateLoanProduct(_ product: LoanProduct) async throws -> Loan_V1_LoanProduct {
        try await perform(product.protoUpdateRequest, authorized: true) { service, req, metadata in
            try await service.updateLoanProduct(req, metadata: metadata).product
        }
    }

    func deleteLoanProduct(productID: String) async throws {
        var request = Loan_V1_DeleteLoanProductRequest()
        request.productID = productID
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.deleteLoanProduct(req, metadata: metadata)
        }
    }

    func upsertEligibility(productID: String, rule: LoanProduct.EligibilityRule?) async throws {
        var request = Loan_V1_UpsertProductEligibilityRuleRequest()
        request.productID = productID
        if let rule {
            request.minAge = Int32(rule.minAge)
            request.minMonthlyIncome = rule.minMonthlyIncome
            request.minBureauScore = Int32(rule.minBureauScore)
            request.allowedEmploymentTypes = rule.allowedEmploymentTypes
        }
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.upsertProductEligibilityRule(req, metadata: metadata)
        }
    }

    func replaceFees(productID: String, fees: [LoanProduct.Fee]) async throws {
        var request = Loan_V1_ReplaceProductFeesRequest()
        request.productID = productID
        request.items = fees.map(\.protoInput)
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.replaceProductFees(req, metadata: metadata)
        }
    }

    func replaceRequiredDocuments(productID: String, documents: [LoanProduct.RequiredDocument]) async throws {
        var request = Loan_V1_ReplaceProductRequiredDocumentsRequest()
        request.productID = productID
        request.items = documents.map(\.protoInput)
        _ = try await perform(request, authorized: true) { service, req, metadata in
            try await service.replaceProductRequiredDocuments(req, metadata: metadata)
        }
    }

    func listLoanApplications(
        limit: Int32 = 100,
        offset: Int32 = 0,
        branchID: String? = nil,
        authorized: Bool = true
    ) async throws -> [Loan_V1_LoanApplication] {
        var request = Loan_V1_ListLoanApplicationsRequest()
        request.limit = limit
        request.offset = offset
        if let branchID, !branchID.isEmpty {
            request.branchID = branchID
        }

        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.listLoanApplications(req, metadata: metadata).items
        }
    }

    func getLoanApplication(applicationID: String, authorized: Bool = true) async throws -> Loan_V1_GetLoanApplicationResponse {
        var request = Loan_V1_GetLoanApplicationRequest()
        request.applicationID = applicationID
        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.getLoanApplication(req, metadata: metadata)
        }
    }

    func createLoanApplication(
        primaryBorrowerProfileID: String,
        loanProductID: String,
        branchID: String,
        requestedAmount: String,
        tenureMonths: Int32,
        status: Loan_V1_LoanApplicationStatus = .submitted,
        authorized: Bool = true
    ) async throws -> Loan_V1_LoanApplication {
        var request = Loan_V1_CreateLoanApplicationRequest()
        request.primaryBorrowerProfileID = primaryBorrowerProfileID
        request.loanProductID = loanProductID
        request.branchID = branchID
        request.requestedAmount = requestedAmount
        request.tenureMonths = tenureMonths
        request.status = status

        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.createLoanApplication(req, metadata: metadata).application
        }
    }

    func updateLoanApplicationStatus(
        applicationID: String,
        status: Loan_V1_LoanApplicationStatus,
        escalationReason: String? = nil,
        authorized: Bool = true
    ) async throws -> Bool {
        var request = Loan_V1_UpdateLoanApplicationStatusRequest()
        request.applicationID = applicationID
        request.status = status
        if let escalationReason {
            request.escalationReason = escalationReason
        }

        return try await perform(request, authorized: authorized) { service, req, metadata in
            try await service.updateLoanApplicationStatus(req, metadata: metadata).success
        }
    }

    // MARK: - Loan Servicing (Post-Disbursement)

    /// Creates the loan ledger after manager approval. Triggers EMI schedule generation.
    func createLoan(applicationID: String, principalAmount: String) async throws -> Loan_V1_Loan {
        var req = Loan_V1_CreateLoanRequest()
        req.applicationID = applicationID
        req.principalAmount = principalAmount
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.createLoan(r, metadata: metadata).loan
        }
    }

    func getLoan(loanID: String? = nil, applicationID: String? = nil) async throws -> Loan_V1_Loan {
        var req = Loan_V1_GetLoanRequest()
        if let loanID { req.loanID = loanID }
        if let applicationID { req.applicationID = applicationID }
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.getLoan(r, metadata: metadata).loan
        }
    }

    func listLoans(limit: Int32 = 100, offset: Int32 = 0) async throws -> [Loan_V1_Loan] {
        var req = Loan_V1_ListLoansRequest()
        req.limit = limit
        req.offset = offset
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.listLoans(r, metadata: metadata).items
        }
    }

    func listEmiSchedule(loanID: String) async throws -> [Loan_V1_EmiScheduleItem] {
        var req = Loan_V1_ListEmiScheduleRequest()
        req.loanID = loanID
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.listEmiSchedule(r, metadata: metadata).items
        }
    }

    func listPayments(loanID: String) async throws -> [Loan_V1_Payment] {
        var req = Loan_V1_ListPaymentsRequest()
        req.loanID = loanID
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.listPayments(r, metadata: metadata).items
        }
    }

    func recordPayment(
        loanID: String,
        emiScheduleID: String,
        amount: String,
        externalTransactionID: String
    ) async throws -> Loan_V1_Payment {
        var req = Loan_V1_RecordPaymentRequest()
        req.loanID = loanID
        req.emiScheduleID = emiScheduleID
        req.amount = amount
        req.externalTransactionID = externalTransactionID
        req.status = .success
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.recordPayment(r, metadata: metadata).payment
        }
    }

    // MARK: - Document Verification (LO action)

    func updateApplicationDocumentVerification(
        documentID: String,
        verificationStatus: Loan_V1_DocumentVerificationStatus,
        rejectionReason: String? = nil
    ) async throws -> Bool {
        var req = Loan_V1_UpdateApplicationDocumentVerificationRequest()
        req.documentID = documentID
        req.verificationStatus = verificationStatus
        if let reason = rejectionReason { req.rejectionReason = reason }
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.updateApplicationDocumentVerification(r, metadata: metadata).success
        }
    }

    func addApplicationDocument(
        applicationID: String,
        borrowerProfileID: String,
        requiredDocID: String,
        mediaFileID: String
    ) async throws -> Loan_V1_ApplicationDocument {
        var req = Loan_V1_AddApplicationDocumentRequest()
        req.applicationID = applicationID
        req.borrowerProfileID = borrowerProfileID
        req.requiredDocID = requiredDocID
        req.mediaFileID = mediaFileID
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.addApplicationDocument(r, metadata: metadata).document
        }
    }

    // MARK: - Terms & Assignment (Manager/Admin actions)

    func updateLoanApplicationTerms(
        applicationID: String,
        tenureMonths: Int32,
        offeredInterestRate: String
    ) async throws -> Loan_V1_LoanApplication {
        var req = Loan_V1_UpdateLoanApplicationTermsRequest()
        req.applicationID = applicationID
        req.tenureMonths = tenureMonths
        req.offeredInterestRate = offeredInterestRate
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.updateLoanApplicationTerms(r, metadata: metadata).application
        }
    }

    func assignLoanApplicationOfficer(
        applicationID: String,
        officerUserID: String
    ) async throws -> Bool {
        var req = Loan_V1_AssignLoanApplicationOfficerRequest()
        req.applicationID = applicationID
        req.officerUserID = officerUserID
        return try await perform(req, authorized: true) { service, r, metadata in
            try await service.assignLoanApplicationOfficer(r, metadata: metadata).success
        }
    }

    private func perform<Request, Result>(
        _ request: Request,
        authorized: Bool,
        operation: @escaping @Sendable (Loan_V1_LoanService.Client<HTTP2ClientTransport.Posix>, Request, Metadata) async throws -> Result
    ) async throws -> Result {
        do {
            if authorized {
                return try await CoreAPIClient.withAuthorizedClient { client, metadata in
                    let service = Loan_V1_LoanService.Client(wrapping: client)
                    return try await operation(service, request, metadata)
                }
            } else {
                return try await CoreAPIClient.withClient { client in
                    let service = Loan_V1_LoanService.Client(wrapping: client)
                    return try await operation(service, request, CoreAPIClient.anonymousMetadata())
                }
            }
        } catch {
            throw APIError.from(error)
        }
    }
}
