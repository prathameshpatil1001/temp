import Foundation

struct LoanProduct: Identifiable, Hashable {
    var id: String
    var name: String
    var category: Loan_V1_LoanProductCategory
    var interestType: Loan_V1_InterestType
    var baseInterestRate: String
    var minAmount: String
    var maxAmount: String
    var isRequiringCollateral: Bool
    var isActive: Bool
    var isDeleted: Bool
    var createdAt: String
    var updatedAt: String
    var eligibilityRule: EligibilityRule?
    var fees: [Fee]
    var requiredDocuments: [RequiredDocument]

    struct EligibilityRule: Codable, Hashable {
        var id: String
        var minAge: Int
        var minMonthlyIncome: String
        var minBureauScore: Int
        var allowedEmploymentTypes: [String]
    }

    struct Fee: Identifiable, Hashable {
        var id: String
        var type: Loan_V1_ProductFeeType
        var calcMethod: Loan_V1_FeeCalcMethod
        var value: String
    }

    struct RequiredDocument: Identifiable, Hashable {
        var id: String
        var requirementType: Loan_V1_DocumentRequirementType
        var isMandatory: Bool
    }

    init(
        id: String,
        name: String,
        category: Loan_V1_LoanProductCategory,
        interestType: Loan_V1_InterestType,
        baseInterestRate: String,
        minAmount: String,
        maxAmount: String,
        isRequiringCollateral: Bool,
        isActive: Bool,
        isDeleted: Bool = false,
        createdAt: String = "",
        updatedAt: String = "",
        eligibilityRule: EligibilityRule? = nil,
        fees: [Fee] = [],
        requiredDocuments: [RequiredDocument] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.interestType = interestType
        self.baseInterestRate = baseInterestRate
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.isRequiringCollateral = isRequiringCollateral
        self.isActive = isActive
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.eligibilityRule = eligibilityRule
        self.fees = fees
        self.requiredDocuments = requiredDocuments
    }
}

extension LoanProduct {
    init(proto: Loan_V1_LoanProduct) {
        self.init(
            id: proto.id,
            name: proto.name,
            category: proto.category,
            interestType: proto.interestType,
            baseInterestRate: proto.baseInterestRate,
            minAmount: proto.minAmount,
            maxAmount: proto.maxAmount,
            isRequiringCollateral: proto.isRequiringCollateral,
            isActive: proto.isActive,
            isDeleted: proto.isDeleted,
            createdAt: proto.createdAt,
            updatedAt: proto.updatedAt,
            eligibilityRule: proto.eligibilityRule.id.isEmpty && proto.eligibilityRule.minAge == 0 && proto.eligibilityRule.minMonthlyIncome.isEmpty && proto.eligibilityRule.minBureauScore == 0 && proto.eligibilityRule.allowedEmploymentTypes.isEmpty ? nil : .init(proto: proto.eligibilityRule),
            fees: proto.fees.map(Fee.init(proto:)),
            requiredDocuments: proto.requiredDocuments.map(RequiredDocument.init(proto:))
        )
    }

    var protoCreateRequest: Loan_V1_CreateLoanProductRequest {
        var request = Loan_V1_CreateLoanProductRequest()
        request.name = name
        request.category = category
        request.interestType = interestType
        request.baseInterestRate = baseInterestRate
        request.minAmount = minAmount
        request.maxAmount = maxAmount
        request.isRequiringCollateral = isRequiringCollateral
        request.isActive = isActive
        return request
    }

    var protoUpdateRequest: Loan_V1_UpdateLoanProductRequest {
        var request = Loan_V1_UpdateLoanProductRequest()
        request.productID = id
        request.name = name
        request.category = category
        request.interestType = interestType
        request.baseInterestRate = baseInterestRate
        request.minAmount = minAmount
        request.maxAmount = maxAmount
        request.isRequiringCollateral = isRequiringCollateral
        request.isActive = isActive
        return request
    }

    var icon: String {
        switch category {
        case .home: return "house.fill"
        case .vehicle: return isRequiringCollateral ? "car.fill" : "box.truck.fill"
        case .education: return "graduationcap.fill"
        case .personal: return "person.fill"
        default: return "banknote.fill"
        }
    }

    var categoryLabel: String {
        switch category {
        case .home: return "Home"
        case .vehicle: return "Vehicle"
        case .education: return "Education"
        case .personal: return "Personal"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    var statusLabel: String {
        isActive ? "Active" : "Inactive"
    }

    var rateDisplay: String {
        let suffix = interestType == .floating ? " floating" : interestType == .fixed ? " fixed" : ""
        return "\(baseInterestRate)%\(suffix)"
    }

    var amountRangeDisplay: String {
        "\(Self.currency(minAmount)) - \(Self.currency(maxAmount))"
    }

    static func currency(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned) else { return raw }
        if value >= 10_000_000 { return "₹\(String(format: "%.1f", value / 10_000_000))Cr" }
        if value >= 100_000 { return "₹\(String(format: "%.1f", value / 100_000))L" }
        if value >= 1_000 { return "₹\(String(format: "%.0f", value / 1_000))K" }
        return "₹\(String(format: "%.0f", value))"
    }
}

extension LoanProduct.EligibilityRule {
    init(proto: Loan_V1_ProductEligibilityRule) {
        self.init(
            id: proto.id,
            minAge: Int(proto.minAge),
            minMonthlyIncome: proto.minMonthlyIncome,
            minBureauScore: Int(proto.minBureauScore),
            allowedEmploymentTypes: proto.allowedEmploymentTypes
        )
    }

    var protoRequest: Loan_V1_UpsertProductEligibilityRuleRequest {
        var request = Loan_V1_UpsertProductEligibilityRuleRequest()
        request.minAge = Int32(minAge)
        request.minMonthlyIncome = minMonthlyIncome
        request.minBureauScore = Int32(minBureauScore)
        request.allowedEmploymentTypes = allowedEmploymentTypes
        return request
    }
}

extension LoanProduct.Fee {
    init(proto: Loan_V1_ProductFee) {
        self.init(id: proto.id, type: proto.type, calcMethod: proto.calcMethod, value: proto.value)
    }

    var protoInput: Loan_V1_ProductFeeInput {
        var input = Loan_V1_ProductFeeInput()
        input.type = type
        input.calcMethod = calcMethod
        input.value = value
        return input
    }

    var typeLabel: String {
        switch type {
        case .processing: return "Processing"
        case .prepayment: return "Prepayment"
        case .latePayment: return "Late Payment"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    var calcMethodLabel: String {
        switch calcMethod {
        case .flat: return "Flat"
        case .percentage: return "%"
        case .unspecified, .UNRECOGNIZED(_): return ""
        }
    }
}

extension LoanProduct.RequiredDocument {
    init(proto: Loan_V1_ProductRequiredDocument) {
        self.init(id: proto.id, requirementType: proto.requirementType, isMandatory: proto.isMandatory)
    }

    var protoInput: Loan_V1_ProductRequiredDocumentInput {
        var input = Loan_V1_ProductRequiredDocumentInput()
        input.requirementType = requirementType
        input.isMandatory = isMandatory
        return input
    }

    var label: String {
        switch requirementType {
        case .identity: return "Identity"
        case .address: return "Address"
        case .income: return "Income"
        case .collateral: return "Collateral"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }
}
