//
//  ApplicationsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

struct OfficerDirectoryItem: Identifiable, Hashable {
    let id: String
    let name: String
    let branchName: String
}

struct CachedMediaPreview: Sendable {
    let mediaFileID: String
    let fileName: String
    let contentType: String
    let fileURL: URL?
}

@MainActor
class ApplicationsViewModel: ObservableObject {
    @Published var applications: [LoanApplication] = []
    @Published var selectedApplication: LoanApplication? = nil
    @Published var filterStatus: ApplicationStatus? = nil
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showXMLUploadResult = false
    @Published var xmlParseResult: XMLParseResult? = nil
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    // Uploaded file URLs per document id (in-memory for session)
    @Published var uploadedFiles: [String: [UploadedDocFile]] = [:]

    // New Filters for Manager Navigation
    @Published var filterRisk: RiskLevel? = nil
    @Published var filterSLA: SLAStatus? = nil
    @Published var filterHighValue: Bool = false
    @Published var filterLoanType: LoanType? = nil

    // Manager rejection remarks sheet
    @Published var showRejectionRemarksSheet = false
    @Published var pendingRejectionApp: LoanApplication? = nil
    @Published var rejectionRemarksText = ""

    @Published var availableLoanProducts: [LoanProduct] = []
    @Published var availableBranchOfficers: [OfficerDirectoryItem] = []
    @Published var officerDirectoryUnavailableMessage: String? = nil
    @Published private(set) var mediaPreviewCache: [String: CachedMediaPreview] = [:]

    // Auth API for fetching profile
    private let authAPI = AuthAPI()
    private let adminAPI = AdminAPI()

    // Manager send back sheet
    @Published var showSendBackSheet = false
    @Published var pendingSendBackApp: LoanApplication? = nil
    @Published var sendBackReason = ""
    @Published var sendBackCustomRemark = ""
    
    @Published var minAmount: Double = 0
    @Published var maxAmount: Double = 100_000_000 // 10 Cr
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    
    // MARK: - Dashboard Context State
    enum DashboardFilterType {
        case none, pending, nearSLA, risky, overdue
    }

    @Published var activeDashboardFilter: DashboardFilterType = .none
    
    private let dataService = MockDataService.shared
    private let xmlService = XMLParserService.shared
    // TODO: Replace with UserStore.shared.branchID once auth session exposes it
    private let defaultBranchID = ""
    
    // MARK: - Sorting State
        @Published var currentSort: SortOption = .newestFirst

        enum SortOption {
            case newestFirst
            case longestInQueue // FIFO
            case highestAmount
        }
    // MARK: - Filtered Applications

    var filteredApplications: [LoanApplication] {
        var result = applications

                // Update this block to strictly filter for all categories
                switch activeDashboardFilter {
                case .pending:
                    result = result.filter { $0.status == .managerReview || $0.status == .officerApproved || $0.status == .underReview }
                case .risky:
                    result = result.filter { $0.riskLevel == .high }
                case .nearSLA:
                    // Strictly show ONLY urgent items (e.g., <= 2 days remaining)
                    result = result.filter { $0.slaStatus == .urgent }
                case .overdue:
                    // Strictly show ONLY overdue items
                    result = result.filter { $0.slaStatus == .overdue }
                case .none:
                    if let status = filterStatus { result = result.filter { $0.status == status } }
                    if let risk = filterRisk { result = result.filter { $0.riskLevel == risk } }
                }
            // 2. LOAN OFFICER ADVANCED FILTERS (KEEP UNTOUCHED)
            // Common search filter
            if !searchText.isEmpty {
                result = result.filter {
                    $0.borrower.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.id.localizedCaseInsensitiveContains(searchText) ||
                    $0.borrower.employer.localizedCaseInsensitiveContains(searchText)
                }
            }

            // Range filters (Amount & Date)
            result = result.filter { $0.loan.amount >= minAmount && $0.loan.amount <= maxAmount }
            result = result.filter { $0.createdAt >= startDate }

            // 3. FINAL SORTING (UNIFIED)
            return result.sorted {
                // DASHBOARD OVERRIDE: If Manager clicked "Overdue" or "Near SLA", force those to top
                if activeDashboardFilter == .overdue {
                    if $0.slaStatus != $1.slaStatus { return $0.slaStatus == .overdue }
                }
                if activeDashboardFilter == .nearSLA {
                    if $0.slaStatus != $1.slaStatus { return $0.slaStatus == .urgent }
                }

                // LOAN OFFICER PRIORITY: Always keep SLA Overdue at the very top
                if $0.slaStatus != $1.slaStatus {
                    return $0.slaStatus == .overdue
                }
                
                // USER SORT: Respect the "Highest Amount" or "Newest" selection
                switch currentSort {
                case .newestFirst:     return $0.createdAt > $1.createdAt
                case .longestInQueue:  return $0.createdAt < $1.createdAt
                case .highestAmount:   return $0.loan.amount > $1.loan.amount
                }
            }
        }

    func resetFiltersToAll() {
        filterStatus = nil
        filterRisk = nil
        filterSLA = nil
        filterHighValue = false
        filterLoanType = nil
        minAmount = 0
                maxAmount = 10_000_000
                startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    }
    
    func updateSort(_ option: SortOption) {
            withAnimation {
                currentSort = option
            }
        }

    // MARK: - Load Data

    func loadAvailableLoanProducts() async {
        guard #available(iOS 18.0, *) else { return }
        do {
            let products = try await LoanAPI().listLoanProducts(limit: 100, offset: 0, includeDeleted: false, authorized: true)
            let mapped = products.map { LoanProduct(proto: $0) }
            self.availableLoanProducts = mapped
        } catch {
            print("Failed to load loan products: \(error)")
        }
    }

    func loadData(autoSelectFirst: Bool = true) {
        isLoading = true
        Task {
            do {
                try await refreshApplications(
                    selectApplicationID: selectedApplication?.id,
                    autoSelectFirst: autoSelectFirst
                )
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load applications from server"
                showActionAlert = true
            }
            isLoading = false
        }
    }

    func selectApplication(_ app: LoanApplication) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedApplication = app
        }
        Task { await refreshSelectedApplicationDetail(applicationID: app.id) }
    }

    func refreshDocumentPreview(documentID: String, applicationID: String) async -> LoanDocument? {
        let selectedDoc = selectedApplication?.documents.first(where: { $0.id == documentID })
        let hasInMemoryUpload = !((uploadedFiles[documentID] ?? []).isEmpty)

        if var selectedDoc {
            if selectedDoc.fileURL == nil {
                selectedDoc = applyCachedPreview(to: selectedDoc)
            }
            if selectedDoc.fileURL != nil || hasInMemoryUpload {
                return selectedDoc
            }
        }

        await refreshSelectedApplicationDetail(applicationID: applicationID)

        if let refreshedSelectedDoc = selectedApplication?.documents.first(where: { $0.id == documentID }) {
            return applyCachedPreview(to: refreshedSelectedDoc)
        }

        return applications
            .first(where: { $0.id == applicationID })?
            .documents
            .first(where: { $0.id == documentID })
            .map(applyCachedPreview)
    }

    // MARK: - LO Actions

    /// Loan Officer sends application to manager (Under Review)
    func sendToManager(_ app: LoanApplication) {
        Task {
            await sendToManagerWithFallback(applicationID: app.id)
        }
    }

    /// Kept for backward-compat — same as sendToManager
    func recommendApplication(_ app: LoanApplication) {
        sendToManager(app)
    }

    func rejectApplication(_ app: LoanApplication) {
        Task {
            await updateApplicationStatus(
                applicationID: app.id,
                status: .officerRejected,
                escalationReason: nil,
                successMessage: "Application rejected"
            )
        }
    }

    func approveApplication(_ app: LoanApplication) {
        Task {
            await approveAndCreateLoan(app)
        }
    }

    func regenerateSanctionLetter(_ app: LoanApplication) {
        // No backend RPC exists for sanction letter generation.
        actionMessage = "Sanction letter generation is not implemented in the backend yet."
        showActionAlert = true
    }

    func revokeSanctionLetter(_ app: LoanApplication) {
        // No backend RPC exists for sanction letter revocation.
        actionMessage = "Sanction letter revocation is not implemented in the backend yet."
        showActionAlert = true
    }

    func beginSendBack(_ app: LoanApplication) {
        pendingSendBackApp = app
        sendBackReason = "Select a reason"
        sendBackCustomRemark = ""
        showSendBackSheet = true
    }

    func confirmSendBack() {
        guard let app = pendingSendBackApp else { return }

        let finalRemark = sendBackReason == "Other"
        ? sendBackCustomRemark
        : (sendBackCustomRemark.isEmpty ? sendBackReason : "\(sendBackReason): \(sendBackCustomRemark)")

        // Record the send back remark as a manager remark message
        sendApplicationMessage(
            applicationId: app.id,
            senderName: "Deepak Mehta",
            senderRole: "Manager",
            text: finalRemark,
            isManagerRemark: true
        )

        Task {
            await updateApplicationStatus(
                applicationID: app.id,
                status: .officerReview,
                escalationReason: finalRemark,
                successMessage: "Application returned to Loan Officer"
            )
        }
        showSendBackSheet = false
        pendingSendBackApp = nil
    }

    func requestDocuments(_ app: LoanApplication) {
        // No backend RPC exists for automated document requests yet.
        actionMessage = "Automated document requests are not implemented in the backend yet. Please contact the borrower directly."
        showActionAlert = true
    }

    // MARK: - Manager Rejection With Remarks

    /// Call this to begin the rejection flow (shows the remarks sheet)
    func beginRejectWithRemarks(_ app: LoanApplication) {
        pendingRejectionApp = app
        rejectionRemarksText = ""
        showRejectionRemarksSheet = true
    }

    /// Confirmed rejection: saves remarks then updates status
    func confirmRejectWithRemarks() {
        guard let app = pendingRejectionApp else { return }
        let remarks = rejectionRemarksText.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await updateApplicationStatus(
                applicationID: app.id,
                status: .managerRejected,
                escalationReason: remarks.isEmpty ? nil : remarks,
                successMessage: "Application rejected"
            )
        }
        showRejectionRemarksSheet = false
        pendingRejectionApp = nil
        rejectionRemarksText = ""
    }

    // MARK: - Backend Creation (Loan Officer)

    @MainActor
    func createBackendApplication(
        borrowerProfileID: String,
        borrowerName: String,
        borrowerPhone: String,
        borrowerEmail: String,
        borrowerAddress: String,
        selectedLoanProduct: LoanProduct,
        requestedAmount: Double,
        tenureMonths: Int,
        monthlyIncome: Double,
        existingEMI: Double,
        documents: [LoanDocument]
    ) async throws -> String {
        let cleanBorrowerProfileID = borrowerProfileID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBorrowerProfileID.isEmpty else {
            throw APIError.invalidArgument("Borrower profile ID is required.")
        }
        guard requestedAmount > 0 else {
            throw APIError.invalidArgument("Requested loan amount must be greater than 0.")
        }
        guard tenureMonths > 0 else {
            throw APIError.invalidArgument("Tenure must be greater than 0.")
        }

        guard #available(iOS 18.0, *) else {
            throw APIError.failedPrecondition("Loan application APIs require iOS 18 or later.")
        }

        let profile = try await authAPI.getMyProfile()
        guard case .officerProfile(let officerProfile) = profile.profile else {
            throw APIError.permissionDenied("Only Officer profile can create applications from this screen.")
        }
        let branchID = officerProfile.branch.branchID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branchID.isEmpty else {
            throw APIError.failedPrecondition("Officer is not assigned to a branch.")
        }

        let created = try await LoanAPI().createLoanApplication(
            primaryBorrowerProfileID: cleanBorrowerProfileID,
            loanProductID: selectedLoanProduct.id,
            branchID: branchID,
            requestedAmount: String(Int(requestedAmount)),
            tenureMonths: Int32(tenureMonths),
            status: .submitted
        )

        let localApp = LoanApplication(
            id: created.id,
            borrower: Borrower(
                name: borrowerName.isEmpty ? "Borrower" : borrowerName,
                dob: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
                address: borrowerAddress.isEmpty ? "Address TBD" : borrowerAddress,
                employer: "To be verified",
                employmentType: "To be verified",
                phone: borrowerPhone,
                email: borrowerEmail
            ),
            loan: LoanDetails(
                amount: requestedAmount,
                type: selectedLoanProduct.loanTypeForUI,
                tenure: tenureMonths,
                interestRate: Double(created.offeredInterestRate) ?? 0,
                emi: 0
            ),
            financials: Financials(
                monthlyIncome: monthlyIncome,
                annualIncome: monthlyIncome * 12,
                existingEMI: existingEMI,
                dtiRatio: monthlyIncome > 0 ? (existingEMI / monthlyIncome) : 0,
                cibilScore: 0,
                bankBalance: 0,
                foir: 0,
                ltvRatio: 0,
                proposedEMI: 0
            ),
            documents: documents,
            verification: [],
            notes: [],
            internalRemarks: [],
            status: ApplicationStatus(proto: created.status),
            assignedTo: created.assignedOfficerUserID.isEmpty ? created.createdByUserID : created.assignedOfficerUserID,
            primaryBorrowerProfileID: cleanBorrowerProfileID,
            createdByUserID: created.createdByUserID,
            branch: created.branchName.isEmpty ? officerProfile.branch.name : created.branchName,
            riskLevel: .medium,
            createdAt: Date(),
            slaDeadline: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )

        withAnimation {
            applications.insert(localApp, at: 0)
            selectedApplication = localApp
        }
        return localApp.id
    }

    // MARK: - Document Verification

    func verifyDocument(documentId: String, applicationId: String, approved: Bool, rejectionReason: String? = nil) {
        Task {
            await verifyDocumentInternal(documentId: documentId, applicationId: applicationId, approved: approved, rejectionReason: rejectionReason)
        }
    }

    private func verifyDocumentInternal(documentId: String, applicationId: String, approved: Bool, rejectionReason: String?) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Document verification requires iOS 18 or later"
            showActionAlert = true
            return
        }
        do {
            // Proto uses .pass / .fail — NOT .verified / .rejected
            let status: Loan_V1_DocumentVerificationStatus = approved ? .pass : .fail
            _ = try await LoanAPI().updateApplicationDocumentVerification(
                documentID: documentId,
                verificationStatus: status,
                rejectionReason: rejectionReason
            )
            if let appIdx = applications.firstIndex(where: { $0.id == applicationId }) {
                if let docIdx = applications[appIdx].documents.firstIndex(where: { $0.id == documentId }) {
                    withAnimation {
                        applications[appIdx].documents[docIdx].status = approved ? .verified : .rejected
                        if selectedApplication?.id == applicationId {
                            selectedApplication = applications[appIdx]
                        }
                    }
                }
            }
            actionMessage = approved ? "Document verified successfully" : "Document marked as rejected"
            showActionAlert = true
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update document verification"
            showActionAlert = true
        }
    }

    // MARK: - Assign Officer

    func assignOfficer(applicationId: String, officerUserId: String) {
        Task {
            guard #available(iOS 18.0, *) else { return }
            do {
                _ = try await LoanAPI().assignLoanApplicationOfficer(
                    applicationID: applicationId,
                    officerUserID: officerUserId
                )
                try await refreshApplications(selectApplicationID: applicationId, autoSelectFirst: true)
                actionMessage = "Loan Officer assigned successfully"
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to assign officer"
                showActionAlert = true
            }
        }
    }

    func loadBranchOfficers(branchName: String) {
        Task {
            do {
                let employees = try await adminAPI.listEmployeeAccounts(limit: 500, offset: 0)
                let normalizedBranch = branchName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let mapped = employees.compactMap { account -> OfficerDirectoryItem? in
                    guard account.role == .officer, account.isActive else { return nil }
                    let candidateBranch = account.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !normalizedBranch.isEmpty && candidateBranch.lowercased() != normalizedBranch {
                        return nil
                    }
                    let resolvedName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return OfficerDirectoryItem(
                        id: account.userID,
                        name: resolvedName.isEmpty ? account.email : resolvedName,
                        branchName: candidateBranch
                    )
                }
                availableBranchOfficers = mapped.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
                officerDirectoryUnavailableMessage = mapped.isEmpty
                    ? "Officer directory is currently unavailable for this branch. Reassignment will be enabled once branch officer data is available."
                    : nil
            } catch {
                availableBranchOfficers = []
                officerDirectoryUnavailableMessage = "Officer directory is currently unavailable. Manager can view Reassign, but reassignment options are temporarily unavailable."
            }
        }
    }

    func officerDisplayName(for userID: String) -> String {
        guard !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "Unassigned" }
        if let match = availableBranchOfficers.first(where: { $0.id == userID }) {
            return match.name
        }
        return userID
    }

    // MARK: - Update Loan Terms

    func updateLoanTerms(applicationId: String, tenureMonths: Int, offeredInterestRate: Double) {
        Task {
            guard #available(iOS 18.0, *) else { return }
            do {
                let updatedApp = try await LoanAPI().updateLoanApplicationTerms(
                    applicationID: applicationId,
                    tenureMonths: Int32(tenureMonths),
                    offeredInterestRate: String(format: "%.2f", offeredInterestRate)
                )
                let mapped = LoanApplication.from(proto: updatedApp)
                if let idx = applications.firstIndex(where: { $0.id == applicationId }) {
                    withAnimation {
                        applications[idx] = mapped
                        if selectedApplication?.id == applicationId {
                            selectedApplication = mapped
                        }
                    }
                }
                actionMessage = "Loan terms updated successfully"
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update loan terms"
                showActionAlert = true
            }
        }
    }

    // MARK: - XML Upload

    func simulateXMLUpload() {
        xmlParseResult = xmlService.simulateXMLUpload()
        showXMLUploadResult = true
    }

    /// Parse XML silently (no result sheet) — used by CreateApplicationSheet for autofill
    func parseXMLFile(_ data: Data) {
        xmlParseResult = xmlService.parseXMLData(data)
        showXMLUploadResult = true
    }

    // MARK: - Per-Application Conversation

    @Published var applicationMessages: [String: [ApplicationMessage]] = [:]
    @Published var chatText = ""

    func loadApplicationMessages(for applicationId: String) {
        if applicationMessages[applicationId] == nil {
            applicationMessages[applicationId] = dataService.fetchApplicationMessages(applicationId: applicationId)
        }
    }

    func messagesForApplication(_ applicationId: String) -> [ApplicationMessage] {
        return applicationMessages[applicationId] ?? []
    }

    // MARK: - Internal Remarks

    func addInternalRemark(applicationId: String, text: String, author: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let remark = InternalRemark(
            id: UUID().uuidString,
            author: author,
            text: text,
            timestamp: Date()
        )
        if let idx = applications.firstIndex(where: { $0.id == applicationId }) {
            withAnimation {
                applications[idx].internalRemarks.append(remark)
                selectedApplication = applications[idx]
            }
        }
    }

    // MARK: - Document Upload

    func addOtherDocument(to app: LoanApplication, label: String) {
        let newDoc = LoanDocument(
            id: "DOC-OTHER-\(UUID().uuidString.prefix(6))",
            type: .other,
            label: label,
            status: .pending,
            uploadedAt: nil
        )
        if let idx = applications.firstIndex(where: { $0.id == app.id }) {
            withAnimation {
                applications[idx].documents.append(newDoc)
                selectedApplication = applications[idx]
            }
        }
    }

    func recordUploadedFile(_ file: UploadedDocFile, forDocumentId docId: String) {
        withAnimation {
            if uploadedFiles[docId] != nil {
                uploadedFiles[docId]!.append(file)
            } else {
                uploadedFiles[docId] = [file]
            }
        }
        // Mark document as uploaded in the application
        if let appIdx = applications.firstIndex(where: { app in
            app.documents.contains(where: { $0.id == docId })
        }) {
            if let docIdx = applications[appIdx].documents.firstIndex(where: { $0.id == docId }) {
                withAnimation {
                    applications[appIdx].documents[docIdx].status = .uploaded
                    applications[appIdx].documents[docIdx].uploadedAt = Date()
                    selectedApplication = applications[appIdx]
                }
            }
        }
    }

    func uploadSanctionLetter(application: LoanApplication, data: Data, fileName: String, contentType: String) {
        Task {
            guard #available(iOS 18.0, *) else {
                actionMessage = "Sanction letter upload requires iOS 18 or later."
                showActionAlert = true
                return
            }

            let borrowerProfileID = application.primaryBorrowerProfileID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !borrowerProfileID.isEmpty else {
                actionMessage = "Borrower profile details are unavailable for this application. Please refresh and try again."
                showActionAlert = true
                return
            }

            do {
                let uploadedMedia = try await MediaAPI().uploadFile(data: data, fileName: fileName, contentType: contentType)
                cacheMediaPreview(uploadedMedia)
                _ = try await LoanAPI().addApplicationDocument(
                    applicationID: application.id,
                    borrowerProfileID: borrowerProfileID,
                    requiredDocID: "sanction_letter_manual",
                    mediaFileID: uploadedMedia.mediaID
                )
                try await refreshApplications(selectApplicationID: application.id, autoSelectFirst: true)
                actionMessage = "Sanction letter uploaded successfully."
                showActionAlert = true
            } catch {
                actionMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to upload sanction letter."
                showActionAlert = true
            }
        }
    }

    func sendApplicationMessage(applicationId: String, senderName: String, senderRole: String, text: String? = nil, isManagerRemark: Bool = false) {
        let textToSend = text ?? chatText
        guard !textToSend.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let msg = ApplicationMessage(
            id: "\(applicationId)-AM-\(UUID().uuidString.prefix(6))",
            applicationId: applicationId,
            senderId: isManagerRemark ? "MGR-001" : "LO-001",
            senderName: senderName,
            senderRole: senderRole,
            text: textToSend,
            timestamp: Date(),
            type: isManagerRemark ? .managerRemark : .message,
            isFromCurrentUser: true
        )
        withAnimation {
            if applicationMessages[applicationId] != nil {
                applicationMessages[applicationId]!.append(msg)
            } else {
                applicationMessages[applicationId] = [msg]
            }
        }
        if text == nil {
            chatText = ""
        }
    }

    // MARK: - Borrower Profile Resolution

    @MainActor
    func resolveBorrowerProfileID(email: String, phone: String) async throws -> String? {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

        guard #available(iOS 18.0, *) else { return nil }

        func exactMatch(from items: [Auth_V1_BorrowerSignupStatusItem]) -> Auth_V1_BorrowerSignupStatusItem? {
            let direct = items.first { item in
                let emailMatch = !cleanEmail.isEmpty && item.email.lowercased() == cleanEmail
                let phoneMatch = !cleanPhone.isEmpty && item.phone == cleanPhone
                return emailMatch || phoneMatch
            }
            if let direct { return direct }
            return items.first
        }

        if !cleanEmail.isEmpty {
            let emailResults: Auth_V1_SearchBorrowerSignupStatusResponse = try await authAPI.searchBorrowerSignupStatus(query: cleanEmail, limit: 20, offset: 0)
            if let found = exactMatch(from: emailResults.items), !found.borrowerProfileId.isEmpty {
                return found.borrowerProfileId
            }
        }

        if !cleanPhone.isEmpty {
            let phoneResults: Auth_V1_SearchBorrowerSignupStatusResponse = try await authAPI.searchBorrowerSignupStatus(query: cleanPhone, limit: 20, offset: 0)
            if let found = exactMatch(from: phoneResults.items), !found.borrowerProfileId.isEmpty {
                return found.borrowerProfileId
            }
        }

        return nil
    }

    // MARK: - Private Backend Helpers

    /// Manager approval: updates status to MANAGER_APPROVED and leaves final disbursal pending borrower acceptance.
    private func approveAndCreateLoan(_ app: LoanApplication) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Approval requires iOS 18 or later"
            showActionAlert = true
            return
        }
        do {
            _ = try await LoanAPI().updateLoanApplicationStatus(
                applicationID: app.id,
                status: .managerApproved,
                escalationReason: nil
            )
            try await refreshApplications(selectApplicationID: app.id, autoSelectFirst: true)
            actionMessage = "Application approved. Borrower must accept the sanction letter before disbursal."
            showActionAlert = true
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to approve application"
            showActionAlert = true
        }
    }

    private func updateApplicationStatus(
        applicationID: String,
        status: Loan_V1_LoanApplicationStatus,
        escalationReason: String?,
        successMessage: String
    ) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Status update requires iOS 18 or later"
            showActionAlert = true
            return
        }
        do {
            _ = try await LoanAPI().updateLoanApplicationStatus(
                applicationID: applicationID,
                status: status,
                escalationReason: escalationReason
            )
            try await refreshApplications(selectApplicationID: applicationID, autoSelectFirst: true)
            actionMessage = successMessage
            showActionAlert = true
        } catch {
            actionMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update application status"
            showActionAlert = true
        }
    }

    private func sendToManagerWithFallback(applicationID: String) async {
        guard #available(iOS 18.0, *) else {
            actionMessage = "Status update requires iOS 18 or later"
            showActionAlert = true
            return
        }

        // Different deployments can enforce slightly different officer transitions.
        // Try manager escalation first, then officer approval as fallback.
        let statusAttempts: [(Loan_V1_LoanApplicationStatus, String)] = [
            (.managerReview, "Application sent to Manager for review"),
            (.officerApproved, "Application sent to Manager for review"),
            (.officerReview, "Application moved to Officer Review. Send to Manager after approval.")
        ]
        var lastError: Error?

        for (nextStatus, successMessage) in statusAttempts {
            do {
                _ = try await LoanAPI().updateLoanApplicationStatus(
                    applicationID: applicationID,
                    status: nextStatus,
                    escalationReason: nil
                )
                // If officerReview succeeded, silently chain officerApproved immediately
                // so both backend steps happen in a single user action.
                if nextStatus == .officerReview {
                    try? await LoanAPI().updateLoanApplicationStatus(
                        applicationID: applicationID,
                        status: .officerApproved,
                        escalationReason: nil
                    )
                }
                try await refreshApplications(selectApplicationID: applicationID, autoSelectFirst: true)
                actionMessage = "Application sent to Manager for review"
                showActionAlert = true
                return
            } catch {
                lastError = error
            }
        }

        actionMessage = (lastError as? LocalizedError)?.errorDescription ?? "Unable to send application to manager"
        showActionAlert = true
    }

    private func refreshApplications(selectApplicationID: String?, autoSelectFirst: Bool) async throws {
        guard #available(iOS 18.0, *) else {
            throw APIError.failedPrecondition("Loan application APIs require iOS 18 or later.")
        }
        let list = try await LoanAPI().listLoanApplications(limit: 100, offset: 0, branchID: defaultBranchID)
        let mapped = list.map { LoanApplication.from(proto: $0) }
        withAnimation {
            applications = mapped
            if let selectedID = selectApplicationID,
               let selected = mapped.first(where: { $0.id == selectedID }) {
                selectedApplication = selected
            } else if autoSelectFirst {
                selectedApplication = mapped.first
            } else {
                selectedApplication = nil
            }
        }

        if let selectedID = selectedApplication?.id {
            await refreshSelectedApplicationDetail(applicationID: selectedID)
        }
    }

    private func refreshSelectedApplicationDetail(applicationID: String) async {
        guard #available(iOS 18.0, *) else { return }
        do {
            let detail = try await LoanAPI().getLoanApplication(applicationID: applicationID)
            var enriched = LoanApplication.from(proto: detail.application, documents: detail.documents)
            enriched = try await enrichDocumentsWithMedia(enriched)
            if let index = applications.firstIndex(where: { $0.id == applicationID }) {
                applications[index] = enriched
            }
            if selectedApplication?.id == applicationID {
                selectedApplication = enriched
            }
        } catch {
            // Keep list data if detail fetch fails.
        }
    }

    
    private func enrichDocumentsWithMedia(_ application: LoanApplication) async throws -> LoanApplication {
        let mediaIDs: Set<String> = Set(application.documents.compactMap { doc in
            guard let mediaFileID = doc.mediaFileID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !mediaFileID.isEmpty else {
                return nil
            }
            return mediaFileID
        })

        guard !mediaIDs.isEmpty else { return application }

        var matchedMedia: [String: Media_V1_MediaItem] = [:]
        let unresolvedMediaIDs = mediaIDs.filter { mediaPreviewCache[$0] == nil }

        if !unresolvedMediaIDs.isEmpty {
            do {
                var offset: Int32 = 0
                let pageSize: Int32 = 100
                let maxPages = 20

                for _ in 0..<maxPages {
                    let page = try await MediaAPI().listMedia(limit: pageSize, offset: offset)
                    if page.isEmpty { break }

                    for item in page where unresolvedMediaIDs.contains(item.mediaID) {
                        matchedMedia[item.mediaID] = item
                    }

                    if matchedMedia.count == unresolvedMediaIDs.count || page.count < Int(pageSize) {
                        break
                    }
                    offset += pageSize
                }
            } catch {
                // Preserve any locally cached preview URLs even when media listing is not allowed.
            }
        }

        var enriched = application
        enriched.documents = application.documents.map { document in
            var updated = applyCachedPreview(to: document)
            guard let mediaFileID = updated.mediaFileID,
                  let media = matchedMedia[mediaFileID] else {
                return updated
            }

            updated.fileName = media.fileName.isEmpty ? document.fileName : media.fileName
            updated.contentType = media.contentType.isEmpty ? document.contentType : media.contentType
            if !media.fileUrl.isEmpty {
                updated.fileURL = URL(string: media.fileUrl)
            }
            return updated
        }
        return enriched
    }

    func cacheMediaPreview(_ uploadedMedia: UploadedMedia) {
        mediaPreviewCache[uploadedMedia.mediaID] = CachedMediaPreview(
            mediaFileID: uploadedMedia.mediaID,
            fileName: uploadedMedia.fileName,
            contentType: uploadedMedia.contentType,
            fileURL: uploadedMedia.fileURL
        )
    }

    private func applyCachedPreview(to document: LoanDocument) -> LoanDocument {
        guard let mediaFileID = document.mediaFileID,
              let cachedPreview = mediaPreviewCache[mediaFileID] else {
            return document
        }

        var updated = document
        if updated.fileName?.isEmpty != false {
            updated.fileName = cachedPreview.fileName
        }
        if updated.contentType?.isEmpty != false {
            updated.contentType = cachedPreview.contentType
        }
        if updated.fileURL == nil {
            updated.fileURL = cachedPreview.fileURL
        }
        return updated
    }
}

// MARK: - Uploaded Doc File

struct UploadedDocFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL?
    var data: Data? = nil
    let contentType: String?
    let isImage: Bool
    let uploadedAt: Date
}


// MARK: - 1. Add the Data Model here
struct NPADataPoint: Identifiable {
    let id = UUID()
    let category: String
    let npaCount: Int
    let totalCount: Int
    var npaRatio: Double {
        totalCount > 0 ? (Double(npaCount) / Double(totalCount)) * 100 : 0
    }
}

// MARK: - 2. Add the Extension here
extension ApplicationsViewModel {
    /// Identify NPA Loans (Overdue > 90 days)
    var npaLoans: [LoanApplication] {
        applications.filter { $0.slaDeadline.daysRemaining < -90 }
    }

    /// Group by Loan Type
    var npaByLoanType: [NPADataPoint] {
        let groups = Dictionary(grouping: applications, by: { $0.loan.type.displayName })
        return groups.map { (key, apps) in
            NPADataPoint(category: key,
                         npaCount: apps.filter { $0.slaDeadline.daysRemaining < -90 }.count,
                         totalCount: apps.count)
        }.sorted { $0.npaCount > $1.npaCount }
    }

    /// Group by Tenure Buckets
    var npaByTenure: [NPADataPoint] {
        func getBucket(_ months: Int) -> String {
            if months <= 12 { return "0-1 yr" }
            if months <= 36 { return "1-3 yr" }
            return "3+ yr"
        }
        let groups = Dictionary(grouping: applications, by: { getBucket($0.loan.tenure) })
        return groups.map { (key, apps) in
            NPADataPoint(category: key,
                         npaCount: apps.filter { $0.slaDeadline.daysRemaining < -90 }.count,
                         totalCount: apps.count)
        }
    }
}



private extension LoanProduct {
    var loanTypeForUI: LoanType {
        switch category {
        case .home:
            return .homeLoan
        case .vehicle:
            return .vehicleLoan
        case .education:
            return .educationLoan
        case .personal:
            return .personalLoan
        case .unspecified, .UNRECOGNIZED:
            return .businessLoan
        }
    }
}
