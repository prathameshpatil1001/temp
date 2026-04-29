import Foundation
import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class LoanApplicationViewModel: ObservableObject {

    @Published var selectedProductId: String = ""
    @Published var selectedBranchId: String = ""
    @Published var detectedBranchName: String = ""
    @Published var branches: [BorrowerBranch] = []
    @Published var isLoadingBranches: Bool = false
    @Published var branchLoadError: String? = nil
    @Published var requestedAmount: String = ""
    @Published var tenureMonths: Int = 12
    @Published var borrowerProfileId: String = ""
    @Published var disbursementAccountNumber: String = ""
    @Published var disbursementIfscCode: String = ""
    @Published var disbursementBankName: String = ""
    @Published var disbursementAccountHolderName: String = ""

    @Published var isSubmitting: Bool = false
    @Published var submissionError: String? = nil
    @Published var submittedApplication: BorrowerLoanApplication? = nil
    @Published var isApplicationSubmitted: Bool = false

    private let service: LoanServiceProtocol
    private let branchService: BranchServiceProtocol

    init(
        service: LoanServiceProtocol = ServiceContainer.loanService,
        branchService: BranchServiceProtocol = ServiceContainer.branchService
    ) {
        self.service = service
        self.branchService = branchService
    }

    func preloadSubmissionContext() {
        Task {
            isLoadingBranches = true
            branchLoadError = nil
            do {
                async let branchesTask = branchService.listBranches(limit: 200, offset: 0)
                async let existingApplicationsTask = service.listLoanApplications(limit: 20, offset: 0)

                let availableBranches = try await branchesTask.sorted(by: { $0.name < $1.name })
                let existingApplications = try await existingApplicationsTask

                branches = availableBranches
                if selectedBranchId.isEmpty, let latestApplication = existingApplications.first,
                   availableBranches.contains(where: { $0.id == latestApplication.branchId }) {
                    selectedBranchId = latestApplication.branchId
                }
                if selectedBranchId.isEmpty, let firstBranch = availableBranches.first {
                    selectedBranchId = firstBranch.id
                }
                if let selected = availableBranches.first(where: { $0.id == selectedBranchId }) {
                    detectedBranchName = selected.name
                } else if let latestApplication = existingApplications.first {
                    detectedBranchName = latestApplication.branchName
                }
            } catch {
                branches = []
                branchLoadError = (error as? LocalizedError)?.errorDescription ?? "Failed to load branches."
            }
            isLoadingBranches = false
        }
    }

    func updateSelectedBranch(_ branchID: String) {
        selectedBranchId = branchID
        if let selected = branches.first(where: { $0.id == branchID }) {
            detectedBranchName = selected.name
            submissionError = nil
        } else if branchID.isEmpty {
            detectedBranchName = ""
        }
    }

    func selectedBranchLocation() -> String {
        guard let selected = branches.first(where: { $0.id == selectedBranchId }) else {
            return ""
        }
        return selected.locationLabel
    }

    func canSubmit() -> Bool {
        !isSubmitting && !selectedBranchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !branches.isEmpty
    }

    func canProceedToDisbursementDetails() -> Bool {
        canSubmit()
    }

    func retryLoadingBranches() {
        preloadSubmissionContext()
    }

    func ensureBranchValidityBeforeSubmit() -> Bool {
        let trimmedBranchId = selectedBranchId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branches.isEmpty else {
            submissionError = "No branches are available right now. Please try again shortly."
            return false
        }
        guard !trimmedBranchId.isEmpty else {
            submissionError = "Please choose a branch."
            return false
        }
        guard branches.contains(where: { $0.id == trimmedBranchId }) else {
            submissionError = "Please select a valid branch from the list."
            return false
        }
        return true
    }

    func validateDisbursementDetails() -> Bool {
        let trimmedAccountNumber = disbursementAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIFSC = disbursementIfscCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedBankName = disbursementBankName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccountHolderName = disbursementAccountHolderName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAccountHolderName.isEmpty else {
            submissionError = "Please enter the account holder name."
            return false
        }

        guard !trimmedBankName.isEmpty else {
            submissionError = "Please enter the bank name."
            return false
        }

        guard trimmedAccountNumber.count >= 8, trimmedAccountNumber.allSatisfy(\.isNumber) else {
            submissionError = "Please enter a valid account number."
            return false
        }

        guard isValidIFSC(trimmedIFSC) else {
            submissionError = "Please enter a valid IFSC code."
            return false
        }

        disbursementIfscCode = trimmedIFSC
        submissionError = nil
        return true
    }

    func submitApplication() async -> BorrowerLoanApplication? {
        guard !isSubmitting else { return nil }
        guard ensureBranchValidityBeforeSubmit() else {
            return nil
        }
        guard validateDisbursementDetails() else {
            return nil
        }

        let trimmedProductId = selectedProductId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBranchId = selectedBranchId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAmount = requestedAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccountNumber = disbursementAccountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIFSC = disbursementIfscCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBankName = disbursementBankName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAccountHolderName = disbursementAccountHolderName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedProductId.isEmpty else {
            submissionError = "Loan product is missing. Please reopen the application flow."
            return nil
        }

        guard !trimmedAmount.isEmpty else {
            submissionError = "Please choose a loan amount."
            return nil
        }

        isSubmitting = true
        submissionError = nil
        defer { isSubmitting = false }

        do {
            let application = try await service.createLoanApplication(
                primaryBorrowerProfileId: borrowerProfileId.trimmingCharacters(in: .whitespacesAndNewlines),
                loanProductId: trimmedProductId,
                branchId: trimmedBranchId,
                requestedAmount: trimmedAmount,
                tenureMonths: tenureMonths,
                disbursementAccountNumber: trimmedAccountNumber,
                disbursementIfscCode: trimmedIFSC,
                disbursementBankName: trimmedBankName,
                disbursementAccountHolderName: trimmedAccountHolderName
            )
            submittedApplication = application
            isApplicationSubmitted = true
            if detectedBranchName.isEmpty {
                detectedBranchName = application.branchName
            }
            return application
        } catch {
            submissionError = (error as? LocalizedError)?.errorDescription ?? "Application failed"
            return nil
        }
    }

    func checkEligibility(product: LoanProduct, monthlySalary: Double, age: Int) -> String? {
        if let rule = product.eligibilityRule {
            if age < rule.minAge {
                return "Minimum age is \(rule.minAge) years."
            }
            if let minIncome = Double(rule.minMonthlyIncome), monthlySalary < minIncome {
                return "Minimum monthly income required is ₹\(rule.minMonthlyIncome)."
            }
        }
        if let amount = Double(requestedAmount),
           let min = Double(product.minAmount),
           let max = Double(product.maxAmount),
           amount < min || amount > max {
            return "Loan amount must be between ₹\(product.minAmount) and ₹\(product.maxAmount)."
        }
        return nil
    }

    private func isValidIFSC(_ value: String) -> Bool {
        let pattern = "^[A-Z]{4}0[A-Z0-9]{6}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

}
