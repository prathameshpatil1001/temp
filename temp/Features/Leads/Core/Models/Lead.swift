import SwiftUI

// MARK: - Lead Status
enum LeadStatus: String, CaseIterable, Identifiable, Codable, Hashable {
    case new         = "New"
    case docsPending = "Docs Pending"
    case submitted   = "Submitted"
    case rejected    = "Rejected"
    case approved    = "Approved"
    case disbursed   = "Disbursed"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var dotColor: Color {
        switch self {
        case .new:         return .statusNew
        case .docsPending: return .statusPending
        case .submitted:   return .statusSubmitted
        case .rejected:    return .statusRejected
        case .approved:    return .statusApproved
        case .disbursed:   return .statusDisbursed
        }
    }
    var textColor: Color { dotColor }
    var backgroundColor: Color {
        switch self {
        case .new:         return .statusNewBg
        case .docsPending: return .statusPendingBg
        case .submitted:   return .statusSubmittedBg
        case .rejected:    return .statusRejectedBg
        case .approved:    return .statusApprovedBg
        case .disbursed:   return .statusDisbursedBg
        }
    }
}

// MARK: - Loan Type
enum LoanType: String, CaseIterable, Codable, Hashable {
    case home      = "Home Loan"
    case personal  = "Personal Loan"
    case auto      = "Car Loan"
    case education = "Education Loan"
    case business  = "Business Loan"

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .personal:  return "person.fill"
        case .auto:      return "car.fill"
        case .education: return "graduationcap.fill"
        case .business:  return "briefcase.fill"
        }
    }
    var defaultRate: Double {
        switch self {
        case .home:      return 10.75
        case .personal:  return 14.0
        case .auto:      return 9.5
        case .education: return 10.0
        case .business:  return 12.0
        }
    }
    var defaultTenureMonths: Int {
        switch self {
        case .home:      return 240
        case .personal:  return 60
        case .auto:      return 84
        case .education: return 120
        case .business:  return 84
        }
    }
    var foirLimit: Double { 0.50 }
}

// MARK: - Lead Model
struct Lead: Identifiable, Codable, Hashable {
    let id: String
    var applicationID: String?
    var name: String
    var phone: String
    var email: String
    var borrowerProfileID: String?
    var borrowerUserID: String?
    var loanType: LoanType
    var loanProductID: String?      // backend product ID chosen at lead creation
    var loanAmount: Double
    var status: LeadStatus
    var createdAt: Date
    var updatedAt: Date
    var assignedRM: String?
    var branchCode: String?

    // KYC persistence
    var isAadhaarKycVerified: Bool
    var isPanKycVerified: Bool
    var aadhaarVerifiedName: String
    var aadhaarVerifiedDOB: String

    init(
        id: String,
        applicationID: String? = nil,
        name: String,
        phone: String,
        email: String,
        borrowerProfileID: String? = nil,
        borrowerUserID: String? = nil,
        loanType: LoanType,
        loanProductID: String? = nil,
        loanAmount: Double,
        status: LeadStatus,
        createdAt: Date,
        updatedAt: Date,
        assignedRM: String? = nil,
        branchCode: String? = nil,
        isAadhaarKycVerified: Bool = false,
        isPanKycVerified: Bool = false,
        aadhaarVerifiedName: String = "",
        aadhaarVerifiedDOB: String = ""
    ) {
        self.id = id
        self.applicationID = applicationID
        self.name = name
        self.phone = phone
        self.email = email
        self.borrowerProfileID = borrowerProfileID
        self.borrowerUserID = borrowerUserID
        self.loanType = loanType
        self.loanProductID = loanProductID
        self.loanAmount = loanAmount
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.assignedRM = assignedRM
        self.branchCode = branchCode
        self.isAadhaarKycVerified = isAadhaarKycVerified
        self.isPanKycVerified = isPanKycVerified
        self.aadhaarVerifiedName = aadhaarVerifiedName
        self.aadhaarVerifiedDOB = aadhaarVerifiedDOB
    }

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    var formattedAmount: String {
        let lakhs = loanAmount / 100_000
        if lakhs >= 100 {
            return "₹\(String(format: "%.0f", lakhs / 100))Cr"
        } else if loanAmount.truncatingRemainder(dividingBy: 100_000) == 0 {
            return "₹\(Int(lakhs))L"
        } else {
            return "₹\(String(format: "%.1f", lakhs))L"
        }
    }

    var formattedPhone: String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count == 10 else { return "+91 \(phone)" }
        return "+91 \(digits.prefix(5)) \(digits.suffix(5))"
    }

    var timeAgo: String {
        let diff = Calendar.current.dateComponents([.minute, .hour, .day], from: createdAt, to: Date())
        if let day = diff.day, day > 0    { return "\(day)d ago" }
        if let hour = diff.hour, hour > 0 { return "\(hour)h ago" }
        if let min = diff.minute          { return "\(min)m ago" }
        return "Just now"
    }

    var estimatedCommission: Double { loanAmount * 0.0025 }

    var formattedCommission: String {
        let v = Int(estimatedCommission)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return "₹\(fmt.string(from: NSNumber(value: v)) ?? "\(v)")"
    }
}

// MARK: - Filter Model
struct LeadFilter: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let title: String
    let status: LeadStatus?

    static let all = LeadFilter(title: "All", status: nil)
    static var allFilters: [LeadFilter] {
        [.all] + LeadStatus.allCases.map { LeadFilter(title: $0.rawValue, status: $0) }
    }
    static var leadsTabFilters: [LeadFilter] {
        [
            LeadFilter(title: "All",         status: nil),
            LeadFilter(title: "New",          status: .new),
            LeadFilter(title: "Docs Pending", status: .docsPending),
        ]
    }
}
