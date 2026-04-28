import Foundation

@available(iOS 18.0, *)
extension ApplicationStatus {
    init(proto value: Loan_V1_LoanApplicationStatus) {
        switch value {
        // Final approval / disbursement
        case .approved, .disbursed:
            self = .approved
        // Manager approved (loan ledger created)
        case .managerApproved:
            self = .managerApproved
        // Manager rejected
        case .managerRejected:
            self = .managerRejected
        // Officer rejected
        case .officerRejected:
            self = .officerRejected
        // Final rejection / cancellation
        case .rejected, .cancelled:
            self = .rejected
        // Manager review queue
        case .managerReview, .underReview:
            self = .managerReview
        // Officer forwarded to manager
        case .officerApproved:
            self = .officerApproved
        // Officer review queue
        case .officerReview:
            self = .officerReview
        // Submitted but not assigned
        case .submitted:
            self = .officerReview
        // Draft / unspecified
        case .draft, .unspecified, .UNRECOGNIZED:
            self = .pending
        }
    }
}

@available(iOS 18.0, *)
extension LoanApplication {
    static func from(
        proto value: Loan_V1_LoanApplication,
        documents protoDocuments: [Loan_V1_ApplicationDocument] = []
    ) -> LoanApplication {
        let createdAt = Date.fromBackendTimestamp(value.createdAt) ?? Date()
        let updatedAt = Date.fromBackendTimestamp(value.updatedAt) ?? createdAt
        let monthlyIncome = 0.0
        let existingEMI = 0.0

        return LoanApplication(
            id: value.id,
            borrower: Borrower(
                name: value.referenceNumber.isEmpty ? "Borrower \(value.id)" : value.referenceNumber,
                dob: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
                address: "Address not available",
                employer: "Employer not available",
                employmentType: "Unknown",
                phone: "N/A",
                email: "N/A"
            ),
            loan: LoanDetails(
                amount: Double(value.requestedAmount) ?? 0,
                type: LoanType.fromProductName(value.loanProductName),
                tenure: Int(value.tenureMonths),
                interestRate: Double(value.offeredInterestRate) ?? 0,
                emi: 0
            ),
            financials: Financials(
                monthlyIncome: monthlyIncome,
                annualIncome: monthlyIncome * 12,
                existingEMI: existingEMI,
                dtiRatio: 0,
                cibilScore: 0,
                bankBalance: 0,
                foir: 0,
                ltvRatio: 0,
                proposedEMI: 0
            ),
            documents: protoDocuments.map(LoanDocument.from),
            verification: [],
            notes: [],
            internalRemarks: [],
            status: ApplicationStatus(proto: value.status),
            assignedTo: value.assignedOfficerUserID,
            primaryBorrowerProfileID: value.primaryBorrowerProfileID,
            createdByUserID: value.createdByUserID,
            branch: value.branchName.isEmpty ? value.branchID : value.branchName,
            riskLevel: .medium,
            createdAt: createdAt,
            slaDeadline: Calendar.current.date(byAdding: .day, value: 7, to: updatedAt) ?? updatedAt,
            rejectionRemarks: nil
        )
    }
}

@available(iOS 18.0, *)
private extension LoanDocument {
    static func from(proto value: Loan_V1_ApplicationDocument) -> LoanDocument {
        LoanDocument(
            id: value.id.isEmpty ? value.requiredDocID : value.id,
            type: DocumentType.fromRequiredDocID(value.requiredDocID),
            label: DocumentType.fromRequiredDocID(value.requiredDocID).displayName,
            status: DocumentStatus.from(verificationStatus: value.verificationStatus),
            uploadedAt: Date.fromBackendTimestamp(value.createdAt),
            mediaFileID: value.mediaFileID.isEmpty ? nil : value.mediaFileID,
            fileName: nil,
            contentType: nil,
            fileURL: nil
        )
    }
}

@available(iOS 18.0, *)
private extension DocumentStatus {
    static func from(verificationStatus: Loan_V1_DocumentVerificationStatus) -> DocumentStatus {
        switch verificationStatus {
        case .pass:
            return .verified
        case .fail:
            return .rejected
        case .pending:
            return .uploaded
        case .unspecified, .UNRECOGNIZED:
            return .pending
        }
    }
}

private extension DocumentType {
    static func fromRequiredDocID(_ value: String) -> DocumentType {
        let normalized = value.lowercased()
        if normalized.contains("pan") { return .panCard }
        if normalized.contains("aadhaar") || normalized.contains("aadhar") { return .aadhaar }
        if normalized.contains("bank") { return .bankStatement }
        if normalized.contains("salary") { return .salarySlip }
        if normalized.contains("itr") { return .itr }
        return .other
    }
}

private extension LoanType {
    static func fromProductName(_ value: String) -> LoanType {
        let normalized = value.lowercased()
        if normalized.contains("home") { return .homeLoan }
        if normalized.contains("personal") { return .personalLoan }
        if normalized.contains("business") { return .businessLoan }
        if normalized.contains("vehicle") || normalized.contains("car") { return .vehicleLoan }
        if normalized.contains("education") { return .educationLoan }
        return .personalLoan
    }
}

private extension Date {
    static func fromBackendTimestamp(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return Date.iso8601WithFractional.date(from: value)
            ?? Date.iso8601.date(from: value)
    }

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
