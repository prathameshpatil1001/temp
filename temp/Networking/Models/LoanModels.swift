import Foundation

// MARK: - LoanProduct
// Maps to: proto message LoanProduct (loan.proto line 189)
struct LoanProduct: Identifiable, Hashable {
    let id: String                        // proto: id
    let name: String                      // proto: name
    let category: LoanProductCategory     // proto: category (enum)
    let interestType: InterestType        // proto: interest_type (enum)
    let baseInterestRate: String          // proto: base_interest_rate (e.g. "8.5")
    let minAmount: String                 // proto: min_amount (e.g. "50000")
    let maxAmount: String                 // proto: max_amount (e.g. "5000000")
    let isRequiringCollateral: Bool       // proto: is_requiring_collateral
    let isActive: Bool                    // proto: is_active
    let eligibilityRule: ProductEligibilityRule? // proto: eligibility_rule
    let fees: [ProductFee]                // proto: fees
    let requiredDocuments: [ProductRequiredDocument] // proto: required_documents
}

// MARK: - ProductEligibilityRule
// Maps to: proto message ProductEligibilityRule (loan.proto line 181)
struct ProductEligibilityRule: Hashable {
    let id: String
    let minAge: Int                       // proto: min_age
    let minMonthlyIncome: String          // proto: min_monthly_income
    let minBureauScore: Int               // proto: min_bureau_score
    let allowedEmploymentTypes: [String]  // proto: allowed_employment_types
}

// MARK: - ProductFee
// Maps to: proto message ProductFee (loan.proto line 168)
struct ProductFee: Hashable {
    let id: String
    let type: ProductFeeType              // proto: type (enum)
    let calcMethod: FeeCalcMethod         // proto: calc_method (enum)
    let value: String                     // proto: value (e.g. "1.5" or "2000")
}

// MARK: - ProductRequiredDocument
// Maps to: proto message ProductRequiredDocument (loan.proto line 175)
struct ProductRequiredDocument: Hashable {
    let id: String
    let requirementType: DocumentRequirementType // proto: requirement_type (enum)
    let isMandatory: Bool                 // proto: is_mandatory
}

// MARK: - LoanApplication (Borrower view)
// Maps to: proto message LoanApplication (loan.proto line 305)
struct BorrowerLoanApplication: Identifiable, Hashable {
    let id: String                        // proto: id
    let referenceNumber: String           // proto: reference_number
    let primaryBorrowerProfileId: String  // proto: primary_borrower_profile_id
    let loanProductId: String             // proto: loan_product_id
    let loanProductName: String           // proto: loan_product_name
    let branchId: String                  // proto: branch_id
    let branchName: String                // proto: branch_name
    let requestedAmount: String           // proto: requested_amount
    let tenureMonths: Int                 // proto: tenure_months
    let status: LoanApplicationStatus     // proto: status (enum)
    let offeredInterestRate: String       // proto: offered_interest_rate
    let createdAt: String                 // proto: created_at
    let updatedAt: String                 // proto: updated_at
    // Documents attached to this application
    var documents: [BorrowerApplicationDocument]
}

// MARK: - BorrowerApplicationDocument
// Maps to: proto message ApplicationDocument (loan.proto line 496)
struct BorrowerApplicationDocument: Identifiable, Hashable {
    let id: String                        // proto: id
    let applicationId: String             // proto: application_id
    let requiredDocId: String             // proto: required_doc_id
    let mediaFileId: String               // proto: media_file_id
    let verificationStatus: DocumentVerificationStatus // proto: verification_status (enum)
    let rejectionReason: String           // proto: rejection_reason
    let createdAt: String                 // proto: created_at
}

// MARK: - Loan (Active loan post-disbursement)
// Maps to: proto message Loan (loan.proto line 554)
struct ActiveLoan: Identifiable {
    let id: String                        // proto: id
    let applicationId: String             // proto: application_id
    let principalAmount: String           // proto: principal_amount (e.g. "500000")
    let interestRate: String              // proto: interest_rate (e.g. "10.5")
    let emiAmount: String                 // proto: emi_amount
    let outstandingBalance: String        // proto: outstanding_balance
    let status: LoanStatus                // proto: status (enum)
    let createdAt: String                 // proto: created_at
}

// MARK: - EmiScheduleItem
// Maps to: proto message EmiScheduleItem (loan.proto line 596)
struct EmiScheduleItem: Identifiable {
    let id: String                        // proto: id
    let loanId: String                    // proto: loan_id
    let installmentNumber: Int            // proto: installment_number
    let dueDate: String                   // proto: due_date (ISO string e.g. "2025-06-01")
    let emiAmount: String                 // proto: emi_amount
    let status: EmiStatus                 // proto: status (enum)
}

// MARK: - Payment
// Maps to: proto message Payment (loan.proto line 625)
struct LoanPayment: Identifiable {
    let id: String                        // proto: id
    let loanId: String                    // proto: loan_id
    let emiScheduleId: String             // proto: emi_schedule_id
    let amount: String                    // proto: amount
    let externalTransactionId: String     // proto: external_transaction_id
    let status: PaymentStatus             // proto: status (enum)
    let createdAt: String                 // proto: created_at
}
