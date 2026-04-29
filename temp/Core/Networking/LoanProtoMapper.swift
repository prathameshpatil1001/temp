import Foundation

@available(iOS 18.0, *)
extension LoanProduct {
    static func from(proto p: Loan_V1_LoanProduct) -> LoanProduct {
        LoanProduct(
            id: p.id,
            name: p.name,
            category: .from(proto: p.category),
            interestType: .from(proto: p.interestType),
            baseInterestRate: p.baseInterestRate,
            minAmount: p.minAmount,
            maxAmount: p.maxAmount,
            isRequiringCollateral: p.isRequiringCollateral,
            isActive: p.isActive,
            eligibilityRule: p.hasEligibilityRule ? ProductEligibilityRule.from(proto: p.eligibilityRule) : nil,
            fees: p.fees.map(ProductFee.from(proto:)),
            requiredDocuments: p.requiredDocuments.map(ProductRequiredDocument.from(proto:))
        )
    }
}

@available(iOS 18.0, *)
extension ProductEligibilityRule {
    static func from(proto p: Loan_V1_ProductEligibilityRule) -> ProductEligibilityRule {
        ProductEligibilityRule(
            id: p.id,
            minAge: Int(p.minAge),
            minMonthlyIncome: p.minMonthlyIncome,
            minBureauScore: Int(p.minBureauScore),
            allowedEmploymentTypes: p.allowedEmploymentTypes
        )
    }
}

@available(iOS 18.0, *)
extension ProductFee {
    static func from(proto p: Loan_V1_ProductFee) -> ProductFee {
        ProductFee(
            id: p.id,
            type: .from(proto: p.type),
            calcMethod: .from(proto: p.calcMethod),
            value: p.value
        )
    }
}

@available(iOS 18.0, *)
extension ProductRequiredDocument {
    static func from(proto p: Loan_V1_ProductRequiredDocument) -> ProductRequiredDocument {
        ProductRequiredDocument(
            id: p.id,
            requirementType: .from(proto: p.requirementType),
            isMandatory: p.isMandatory
        )
    }
}

@available(iOS 18.0, *)
extension BorrowerLoanApplication {
    static func from(proto p: Loan_V1_LoanApplication) -> BorrowerLoanApplication {
        BorrowerLoanApplication(
            id: p.id,
            referenceNumber: p.referenceNumber,
            primaryBorrowerProfileId: p.primaryBorrowerProfileID,
            loanProductId: p.loanProductID,
            loanProductName: p.loanProductName,
            branchId: p.branchID,
            branchName: p.branchName,
            requestedAmount: p.requestedAmount,
            tenureMonths: Int(p.tenureMonths),
            status: .from(proto: p.status),
            escalationReason: p.escalationReason,
            offeredInterestRate: p.offeredInterestRate,
            disbursementAccountNumber: p.disbursementAccountNumber,
            disbursementIfscCode: p.disbursementIfscCode,
            disbursementBankName: p.disbursementBankName,
            disbursementAccountHolderName: p.disbursementAccountHolderName,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
            documents: []
        )
    }

    static func from(detailResponse response: Loan_V1_GetLoanApplicationResponse) -> BorrowerLoanApplication {
        var application = BorrowerLoanApplication.from(proto: response.application)
        application.documents = response.documents.map(BorrowerApplicationDocument.from(proto:))
        return application
    }
}

@available(iOS 18.0, *)
extension BorrowerApplicationDocument {
    static func from(proto p: Loan_V1_ApplicationDocument) -> BorrowerApplicationDocument {
        BorrowerApplicationDocument(
            id: p.id,
            applicationId: p.applicationID,
            requiredDocId: p.requiredDocID,
            mediaFileId: p.mediaFileID,
            verificationStatus: .from(proto: p.verificationStatus),
            rejectionReason: p.rejectionReason,
            createdAt: p.createdAt
        )
    }
}

@available(iOS 18.0, *)
extension ActiveLoan {
    static func from(proto p: Loan_V1_Loan) -> ActiveLoan {
        ActiveLoan(
            id: p.id,
            applicationId: p.applicationID,
            principalAmount: p.principalAmount,
            interestRate: p.interestRate,
            emiAmount: p.emiAmount,
            outstandingBalance: p.outstandingBalance,
            status: .from(proto: p.status),
            createdAt: p.createdAt
        )
    }
}

@available(iOS 18.0, *)
extension EmiScheduleItem {
    static func from(proto p: Loan_V1_EmiScheduleItem) -> EmiScheduleItem {
        EmiScheduleItem(
            id: p.id,
            loanId: p.loanID,
            installmentNumber: Int(p.installmentNumber),
            dueDate: p.dueDate,
            emiAmount: p.emiAmount,
            status: .from(proto: p.status)
        )
    }
}

@available(iOS 18.0, *)
extension LoanPayment {
    static func from(proto p: Loan_V1_Payment) -> LoanPayment {
        LoanPayment(
            id: p.id,
            loanId: p.loanID,
            emiScheduleId: p.emiScheduleID,
            amount: p.amount,
            externalTransactionId: p.externalTransactionID,
            status: .from(proto: p.status),
            createdAt: p.createdAt
        )
    }
}

@available(iOS 18.0, *)
fileprivate extension LoanProductCategory {
    static func from(proto value: Loan_V1_LoanProductCategory) -> LoanProductCategory {
        switch value {
        case .personal: return .personal
        case .home: return .home
        case .vehicle: return .vehicle
        case .education: return .education
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension InterestType {
    static func from(proto value: Loan_V1_InterestType) -> InterestType {
        switch value {
        case .fixed: return .fixed
        case .floating: return .floating
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension ProductFeeType {
    static func from(proto value: Loan_V1_ProductFeeType) -> ProductFeeType {
        switch value {
        case .processing: return .processing
        case .prepayment: return .prepayment
        case .latePayment: return .latePayment
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension FeeCalcMethod {
    static func from(proto value: Loan_V1_FeeCalcMethod) -> FeeCalcMethod {
        switch value {
        case .flat: return .flat
        case .percentage: return .percentage
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension DocumentRequirementType {
    static func from(proto value: Loan_V1_DocumentRequirementType) -> DocumentRequirementType {
        switch value {
        case .identity: return .identity
        case .address: return .address
        case .income: return .income
        case .collateral: return .collateral
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
extension LoanApplicationStatus {
    static func from(proto value: Loan_V1_LoanApplicationStatus) -> LoanApplicationStatus {
        switch value {
        case .draft: return .draft
        case .submitted: return .submitted
        case .underReview: return .underReview
        case .approved: return .approved
        case .rejected: return .rejected
        case .disbursed: return .disbursed
        case .cancelled: return .cancelled
        case .officerReview: return .officerReview
        case .officerApproved: return .officerApproved
        case .officerRejected: return .officerRejected
        case .managerReview: return .managerReview
        case .managerApproved: return .managerApproved
        case .managerRejected: return .managerRejected
        default: return .unspecified
        }
    }

    var proto: Loan_V1_LoanApplicationStatus {
        switch self {
        case .draft: return .draft
        case .submitted: return .submitted
        case .underReview: return .underReview
        case .approved: return .approved
        case .rejected: return .rejected
        case .disbursed: return .disbursed
        case .cancelled: return .cancelled
        case .officerReview: return .officerReview
        case .officerApproved: return .officerApproved
        case .officerRejected: return .officerRejected
        case .managerReview: return .managerReview
        case .managerApproved: return .managerApproved
        case .managerRejected: return .managerRejected
        case .unspecified: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension DocumentVerificationStatus {
    static func from(proto value: Loan_V1_DocumentVerificationStatus) -> DocumentVerificationStatus {
        switch value {
        case .pending: return .pending
        case .pass: return .pass
        case .fail: return .fail
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension LoanStatus {
    static func from(proto value: Loan_V1_LoanStatus) -> LoanStatus {
        switch value {
        case .active: return .active
        case .closed: return .closed
        case .npa: return .npa
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension EmiStatus {
    static func from(proto value: Loan_V1_EmiStatus) -> EmiStatus {
        switch value {
        case .upcoming: return .upcoming
        case .paid: return .paid
        case .overdue: return .overdue
        default: return .unspecified
        }
    }
}

@available(iOS 18.0, *)
fileprivate extension PaymentStatus {
    static func from(proto value: Loan_V1_PaymentStatus) -> PaymentStatus {
        switch value {
        case .pending: return .pending
        case .success: return .success
        case .failed: return .failed
        default: return .unspecified
        }
    }
}
