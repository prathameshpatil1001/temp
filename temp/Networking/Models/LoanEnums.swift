import SwiftUI

// MARK: - LoanApplicationStatus
// Maps to: proto enum LoanApplicationStatus (loan.proto line 75)
// Full 13-state enum. All states from the proto must be present.
enum LoanApplicationStatus: String, CaseIterable, Codable {
    case unspecified     = "LOAN_APPLICATION_STATUS_UNSPECIFIED"
    case draft           = "LOAN_APPLICATION_STATUS_DRAFT"
    case submitted       = "LOAN_APPLICATION_STATUS_SUBMITTED"
    case underReview     = "LOAN_APPLICATION_STATUS_UNDER_REVIEW"
    case approved        = "LOAN_APPLICATION_STATUS_APPROVED"
    case rejected        = "LOAN_APPLICATION_STATUS_REJECTED"
    case disbursed       = "LOAN_APPLICATION_STATUS_DISBURSED"
    case cancelled       = "LOAN_APPLICATION_STATUS_CANCELLED"
    case officerReview   = "LOAN_APPLICATION_STATUS_OFFICER_REVIEW"
    case officerApproved = "LOAN_APPLICATION_STATUS_OFFICER_APPROVED"
    case officerRejected = "LOAN_APPLICATION_STATUS_OFFICER_REJECTED"
    case managerReview   = "LOAN_APPLICATION_STATUS_MANAGER_REVIEW"
    case managerApproved = "LOAN_APPLICATION_STATUS_MANAGER_APPROVED"
    case managerRejected = "LOAN_APPLICATION_STATUS_MANAGER_REJECTED"

    var displayName: String {
        switch self {
        case .unspecified:     return "Unknown"
        case .draft:           return "Draft"
        case .submitted:       return "Submitted"
        case .underReview:     return "Under Review"
        case .approved:        return "Approved"
        case .rejected:        return "Rejected"
        case .disbursed:       return "Disbursed"
        case .cancelled:       return "Cancelled"
        case .officerReview:   return "Officer Review"
        case .officerApproved: return "Officer Approved"
        case .officerRejected: return "Officer Rejected"
        case .managerReview:   return "Manager Review"
        case .managerApproved: return "Manager Approved"
        case .managerRejected: return "Manager Rejected"
        }
    }

    // Color used in StatusBadge / pill views
    var color: Color {
        switch self {
        case .draft, .submitted:              return .gray
        case .underReview, .officerReview, .managerReview: return .orange
        case .officerApproved, .managerApproved, .approved, .disbursed: return .green
        case .rejected, .officerRejected, .managerRejected, .cancelled: return .red
        default: return .gray
        }
    }
}

// MARK: - LoanProductCategory
// Maps to: proto enum LoanProductCategory (loan.proto line 40)
enum LoanProductCategory: String, CaseIterable, Codable {
    case unspecified = "LOAN_PRODUCT_CATEGORY_UNSPECIFIED"
    case personal    = "LOAN_PRODUCT_CATEGORY_PERSONAL"
    case home        = "LOAN_PRODUCT_CATEGORY_HOME"
    case vehicle     = "LOAN_PRODUCT_CATEGORY_VEHICLE"
    case education   = "LOAN_PRODUCT_CATEGORY_EDUCATION"

    var displayName: String {
        switch self {
        case .unspecified: return "Other"
        case .personal:    return "Personal Loan"
        case .home:        return "Home Loan"
        case .vehicle:     return "Vehicle Loan"
        case .education:   return "Education Loan"
        }
    }
    var icon: String {
        switch self {
        case .personal:    return "person.fill"
        case .home:        return "house.fill"
        case .vehicle:     return "car.fill"
        case .education:   return "graduationcap.fill"
        default:           return "banknote"
        }
    }
}

// MARK: - InterestType
// Maps to: proto enum InterestType (loan.proto line 48)
enum InterestType: String, Codable {
    case unspecified = "INTEREST_TYPE_UNSPECIFIED"
    case fixed       = "INTEREST_TYPE_FIXED"
    case floating    = "INTEREST_TYPE_FLOATING"
    var displayName: String {
        switch self {
        case .fixed:    return "Fixed Rate"
        case .floating: return "Floating Rate"
        default:        return "Unknown"
        }
    }
}

// MARK: - ProductFeeType
// Maps to: proto enum ProductFeeType (loan.proto line 54)
enum ProductFeeType: String, Codable {
    case unspecified  = "PRODUCT_FEE_TYPE_UNSPECIFIED"
    case processing   = "PRODUCT_FEE_TYPE_PROCESSING"
    case prepayment   = "PRODUCT_FEE_TYPE_PREPAYMENT"
    case latePayment  = "PRODUCT_FEE_TYPE_LATE_PAYMENT"
    var displayName: String {
        switch self {
        case .processing:  return "Processing Fee"
        case .prepayment:  return "Prepayment Fee"
        case .latePayment: return "Late Payment Fee"
        default:           return "Fee"
        }
    }
}

// MARK: - FeeCalcMethod
// Maps to: proto enum FeeCalcMethod (loan.proto line 61)
enum FeeCalcMethod: String, Codable {
    case unspecified = "FEE_CALC_METHOD_UNSPECIFIED"
    case flat        = "FEE_CALC_METHOD_FLAT"
    case percentage  = "FEE_CALC_METHOD_PERCENTAGE"
}

// MARK: - DocumentRequirementType
// Maps to: proto enum DocumentRequirementType (loan.proto line 67)
enum DocumentRequirementType: String, Codable {
    case unspecified = "DOCUMENT_REQUIREMENT_TYPE_UNSPECIFIED"
    case identity    = "DOCUMENT_REQUIREMENT_TYPE_IDENTITY"
    case address     = "DOCUMENT_REQUIREMENT_TYPE_ADDRESS"
    case income      = "DOCUMENT_REQUIREMENT_TYPE_INCOME"
    case collateral  = "DOCUMENT_REQUIREMENT_TYPE_COLLATERAL"
    var displayName: String {
        switch self {
        case .identity:   return "Identity Proof"
        case .address:    return "Address Proof"
        case .income:     return "Income Proof"
        case .collateral: return "Collateral Document"
        default:          return "Document"
        }
    }
}

// MARK: - DocumentVerificationStatus
// Maps to: proto enum DocumentVerificationStatus (loan.proto line 126)
enum DocumentVerificationStatus: String, Codable {
    case unspecified = "DOCUMENT_VERIFICATION_STATUS_UNSPECIFIED"
    case pending     = "DOCUMENT_VERIFICATION_STATUS_PENDING"
    case pass        = "DOCUMENT_VERIFICATION_STATUS_PASS"
    case fail        = "DOCUMENT_VERIFICATION_STATUS_FAIL"
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .pass:    return "Verified"
        case .fail:    return "Rejected"
        default:       return "Unknown"
        }
    }
    var color: Color {
        switch self {
        case .pending: return .orange
        case .pass:    return .green
        case .fail:    return .red
        default:       return .gray
        }
    }
}

// MARK: - LoanStatus
// Maps to: proto enum LoanStatus (loan.proto line 140)
enum LoanStatus: String, Codable {
    case unspecified = "LOAN_STATUS_UNSPECIFIED"
    case active      = "LOAN_STATUS_ACTIVE"
    case closed      = "LOAN_STATUS_CLOSED"
    case npa         = "LOAN_STATUS_NPA"
    var displayName: String {
        switch self { case .active: return "Active"; case .closed: return "Closed"; case .npa: return "NPA"; default: return "Unknown" }
    }
}

// MARK: - EmiStatus
// Maps to: proto enum EmiStatus (loan.proto line 147)
enum EmiStatus: String, Codable {
    case unspecified = "EMI_STATUS_UNSPECIFIED"
    case upcoming    = "EMI_STATUS_UPCOMING"
    case paid        = "EMI_STATUS_PAID"
    case overdue     = "EMI_STATUS_OVERDUE"
    var displayName: String {
        switch self { case .upcoming: return "Upcoming"; case .paid: return "Paid"; case .overdue: return "Overdue"; default: return "Unknown" }
    }
    var color: Color {
        switch self { case .upcoming: return .blue; case .paid: return .green; case .overdue: return .red; default: return .gray }
    }
}

// MARK: - PaymentStatus
// Maps to: proto enum PaymentStatus (loan.proto line 154)
enum PaymentStatus: String, Codable {
    case unspecified = "PAYMENT_STATUS_UNSPECIFIED"
    case pending     = "PAYMENT_STATUS_PENDING"
    case success     = "PAYMENT_STATUS_SUCCESS"
    case failed      = "PAYMENT_STATUS_FAILED"
}

// MARK: - BureauProvider
// Maps to: proto enum BureauProvider (loan.proto line 133)
enum BureauProvider: String, Codable {
    case unspecified = "BUREAU_PROVIDER_UNSPECIFIED"
    case cibil       = "BUREAU_PROVIDER_CIBIL"
    case experian    = "BUREAU_PROVIDER_EXPERIAN"
    case equifax     = "BUREAU_PROVIDER_EQUIFAX"
}
