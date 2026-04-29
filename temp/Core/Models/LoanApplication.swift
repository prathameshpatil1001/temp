//
//  LoanApplication.swift
//  lms_project
//

import Foundation

// MARK: - Loan Application

struct LoanApplication: Identifiable, Codable, Hashable {
    let id: String
    var borrower: Borrower
    var loan: LoanDetails
    var financials: Financials
    var documents: [LoanDocument]
    var verification: [VerificationItem]
    var notes: [Note]
    var internalRemarks: [InternalRemark]
    var status: ApplicationStatus
    var assignedTo: String
    var primaryBorrowerProfileID: String = ""
    var createdByUserID: String = ""
    var branch: String
    var riskLevel: RiskLevel
    var createdAt: Date
    var slaDeadline: Date
    /// Populated when manager rejects — saved with the application
    var rejectionRemarks: String?
    
    /// Sanction letter tracking
    var sanctionLetter: SanctionLetter?

    // MARK: - Risk Logic (Add here)
    var isHighRisk: Bool {
            // High Risk IF: CIBIL < 600 OR FOIR > 60% OR Overdue SLA OR Explicit High Risk Level
            financials.cibilScore < 600 ||
            financials.foir > 60 ||
            slaStatus == .overdue ||
            riskLevel == .high
        }
    
    var slaStatus: SLAStatus {
        let days = slaDeadline.daysRemaining
        if days < 0 { return .overdue }
        if days <= 2 { return .urgent }
        return .onTrack
    }
    
    
}

// MARK: - Sanction Letter

struct SanctionLetter: Codable, Hashable {
    var versions: [SanctionLetterVersion]
    var currentVersion: Int
    
    var activeVersion: SanctionLetterVersion? {
        versions.first { $0.version == currentVersion }
    }
}

struct SanctionLetterVersion: Identifiable, Codable, Hashable {
    var id: String { "\(version)" }
    let version: Int
    let generatedAt: Date
    var status: SanctionLetterStatus
    let fileUrl: String
}


// MARK: - Internal Remark

struct InternalRemark: Identifiable, Codable, Hashable {
    let id: String
    var author: String
    var text: String
    var timestamp: Date
}


// MARK: - Borrower

struct Borrower: Codable, Hashable {
    var name: String
    var dob: Date
    var address: String
    var employer: String
    var employmentType: String
    var phone: String
    var email: String
}

// MARK: - Loan Details

struct LoanDetails: Codable, Hashable {
    var amount: Double
    var type: LoanType
    var tenure: Int          // months
    var interestRate: Double  // percentage
    var emi: Double
}

// MARK: - Financials

struct Financials: Codable, Hashable {
    var monthlyIncome: Double
    var annualIncome: Double
    var existingEMI: Double
    var dtiRatio: Double
    var cibilScore: Int
    var bankBalance: Double
    var foir: Double           // percentage
    var ltvRatio: Double       // percentage
    var proposedEMI: Double    // amount
}

// MARK: - Loan Document

struct LoanDocument: Identifiable, Codable, Hashable {
    let id: String
    var type: DocumentType
    var label: String
    var status: DocumentStatus
    var uploadedAt: Date?
    var mediaFileID: String? = nil
    var fileName: String? = nil
    var contentType: String? = nil
    var fileURL: URL? = nil
}

// MARK: - Verification Item

struct VerificationItem: Identifiable, Codable, Hashable {
    let id: String
    var field: String
    var declaredValue: String
    var extractedValue: String
    var isMatch: Bool
}

// MARK: - Note

struct Note: Identifiable, Codable, Hashable {
    let id: String
    var author: String
    var text: String
    var timestamp: Date
}

// MARK: - SLA Status

enum SLAStatus {
    case onTrack
    case urgent
    case overdue
    
    var displayName: String {
        switch self {
        case .onTrack: return "On Track"
        case .urgent: return "Urgent"
        case .overdue: return "Overdue"
        }
    }
    
    var icon: String {
        switch self {
        case .onTrack: return "clock"
        case .urgent: return "exclamationmark.clock"
        case .overdue: return "clock.badge.exclamationmark"
        }
    }
}
