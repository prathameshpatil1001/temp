import SwiftUI
import Foundation

enum LeadDocumentKind: Equatable {
    case aadhaar
    case pan
    case supporting

    var requiresIdentityDetails: Bool {
        switch self {
        case .aadhaar, .pan: return true
        case .supporting: return false
        }
    }
}

struct IdentityVerificationData: Equatable {
    var fullName: String
    var documentNumber: String
    var dateOfBirth: String

    var isComplete: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct DocumentVerification: Equatable {
    var identityData: IdentityVerificationData? = nil
    var note: String? = nil
}

// MARK: - Document Status
enum DocumentStatus: Equatable {
    case verified(date: Date)
    case notUploaded
    case requested(date: Date)
    case uploaded(fileName: String, date: Date)
    case pending

    var isVerified: Bool {
        if case .verified = self { return true }
        return false
    }

    var isUploaded: Bool {
        switch self {
        case .verified, .uploaded, .pending: return true
        case .notUploaded, .requested: return false
        }
    }

    var isAwaitingVerification: Bool {
        switch self {
        case .uploaded, .pending: return true
        case .verified, .notUploaded, .requested: return false
        }
    }

    var requestedAt: Date? {
        if case .requested(let date) = self { return date }
        return nil
    }

    var uploadedAt: Date? {
        if case .uploaded(_, let date) = self { return date }
        return nil
    }

    var uploadedFileName: String? {
        if case .uploaded(let fileName, _) = self { return fileName }
        return nil
    }
}

// MARK: - Lead Document
struct LeadDocument: Identifiable {
    let id: UUID
    let name: String
    let kind: LeadDocumentKind
    var status: DocumentStatus
    var verification: DocumentVerification? = nil

    mutating func requestUpload() {
        status = .requested(date: Date())
    }

    mutating func markUploaded(fileName: String) {
        status = .uploaded(fileName: fileName, date: Date())
    }

    mutating func markPendingVerification() {
        status = .pending
    }

    mutating func markVerified(identityData: IdentityVerificationData? = nil, note: String? = nil) {
        verification = DocumentVerification(identityData: identityData, note: note)
        status = .verified(date: Date())
    }

    static func defaultDocuments(for loanType: LoanType) -> [LeadDocument] {
        // In the DST context, Aadhaar and PAN are collected as photo scans
        // (the borrower presents the physical card). KYC OTP verification
        // happens on the backend after submission.
        let base: [LeadDocument] = [
            LeadDocument(id: UUID(), name: "Aadhaar Card", kind: .supporting, status: .notUploaded),
            LeadDocument(id: UUID(), name: "PAN Card",     kind: .supporting, status: .notUploaded),
        ]

        switch loanType {
        case .home:
            return base + [
                LeadDocument(id: UUID(), name: "Salary Slips (3M)",    kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Bank Statement (6M)",   kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Property Documents",    kind: .supporting, status: .notUploaded),
            ]
        case .personal:
            return base + [
                LeadDocument(id: UUID(), name: "Salary Slips (3M)",    kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Bank Statement (6M)",   kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Employment Letter",     kind: .supporting, status: .notUploaded),
            ]
        case .auto:
            return base + [
                LeadDocument(id: UUID(), name: "Salary Slips (3M)",    kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Bank Statement (6M)",   kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "OEM Proforma Invoice",  kind: .supporting, status: .notUploaded),
            ]
        case .education:
            return base + [
                LeadDocument(id: UUID(), name: "Admission Letter",      kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Fee Structure",          kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Academic Records",       kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Co-Applicant Income",   kind: .supporting, status: .notUploaded),
            ]
        case .business:
            return base + [
                LeadDocument(id: UUID(), name: "ITR (2 Years)",          kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Audited P&L",            kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "GST Certificate",        kind: .supporting, status: .notUploaded),
                LeadDocument(id: UUID(), name: "Bank Statement (6M)",    kind: .supporting, status: .notUploaded),
            ]
        }
    }
}

// MARK: - Timeline Event
struct TimelineEvent: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let time: String
    let isRejected: Bool
}

// MARK: - Lead Message
struct LeadMessage: Identifiable {
    let id: UUID
    let sender: String
    let text: String
    let time: String
    let isMe: Bool
}

// MARK: - Eligibility Result
struct EligibilityResult {
    let isEligible: Bool
    let foir: Double
    let ltv: Double
    let proposedEMI: Double
    let totalEMI: Double
    let keyFactors: [String]
    let foirLimit: Double
}
