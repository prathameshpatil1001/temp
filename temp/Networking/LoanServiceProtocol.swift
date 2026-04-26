// LoanServiceProtocol.swift
// This protocol defines ALL loan backend operations the app needs.
// This protocol defines the borrower loan APIs exposed by the live gRPC backend.

@available(iOS 18.0, *)
protocol LoanServiceProtocol {

    // MARK: - Products (Read)
    // Used by: Borrower (Discover screen) + Employee (Admin config view)
    // Backend: LoanService.ListLoanProducts (loan.proto line 12)
    func listLoanProducts(limit: Int, offset: Int) async throws -> [LoanProduct]

    // Backend: LoanService.GetLoanProduct (loan.proto line 11)
    func getLoanProduct(productId: String) async throws -> LoanProduct

    // MARK: - Applications
    // Used by: Borrower (Apply screen, Track screen)
    // Backend: LoanService.CreateLoanApplication (loan.proto line 17)
    func createLoanApplication(
        primaryBorrowerProfileId: String,
        loanProductId: String,
        branchId: String,
        requestedAmount: String,
        tenureMonths: Int
    ) async throws -> BorrowerLoanApplication

    // Used by: Borrower (Track screen detail)
    // Backend: LoanService.GetLoanApplication (loan.proto line 18)
    func getLoanApplication(applicationId: String) async throws -> BorrowerLoanApplication

    // Used by: Borrower (Track screen list)
    // Backend: LoanService.ListLoanApplications (loan.proto line 19)
    func listLoanApplications(limit: Int, offset: Int) async throws -> [BorrowerLoanApplication]

    // MARK: - Documents
    // Backend: LoanService.AddApplicationDocument (loan.proto line 27)
    // NOTE: media_file_id comes from MediaGRPCClient upload — pass it here
    func addApplicationDocument(
        applicationId: String,
        borrowerProfileId: String,
        requiredDocId: String,
        mediaFileId: String
    ) async throws -> BorrowerApplicationDocument

    // MARK: - Active Loan (Post-Disbursement)
    // Backend: LoanService.GetLoan (loan.proto line 32)
    // Either loan_id or application_id can be passed
    func getLoan(loanId: String?, applicationId: String?) async throws -> ActiveLoan

    // Backend: LoanService.ListLoans (loan.proto line 33)
    func listLoans(limit: Int, offset: Int) async throws -> [ActiveLoan]

    // MARK: - EMI Schedule
    // Backend: LoanService.ListEmiSchedule (loan.proto line 35)
    func listEmiSchedule(loanId: String) async throws -> [EmiScheduleItem]

    // MARK: - Payments
    // Backend: LoanService.ListPayments (loan.proto line 37)
    func listPayments(loanId: String) async throws -> [LoanPayment]

    // Backend: LoanService.RecordPayment (loan.proto line 36)
    // externalTransactionId: a UUID generated client-side to represent the payment gateway TXN
    func recordPayment(
        loanId: String,
        emiScheduleId: String,
        amount: String,
        externalTransactionId: String
    ) async throws -> LoanPayment
}
