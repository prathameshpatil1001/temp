import SwiftUI
import Combine

@MainActor
class AdminLoansViewModel: ObservableObject {
    @Published var loanProducts: [LoanProduct] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var searchText = ""
    @Published var actionMessage: String? = nil
    @Published var showActionAlert = false
    @Published var showAddLoanSheet = false
    @Published var editingLoan: LoanProduct? = nil

    @Published var applications: [LoanApplication] = []
    var totalCount: Int { loanProducts.count }
    var pendingCount: Int { 0 }
    var underReviewCount: Int { 0 }
    var approvedCount: Int { loanProducts.filter(\.isActive).count }
    var rejectedCount: Int { loanProducts.filter { !$0.isActive }.count }

    private let loanAPI = LoanAPI()
    private var hasLoaded = false

    var filteredProducts: [LoanProduct] {
        let products = loanProducts.filter { !$0.isDeleted }
        guard !searchText.isEmpty else { return products }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.categoryLabel.localizedCaseInsensitiveContains(searchText)
            || $0.rateDisplay.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadData(force: Bool = false) {
        guard !hasLoaded || force else { return }
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let products = try await loanAPI.listLoanProducts(includeDeleted: false)
                .filter { !$0.isDeleted }
                .map(LoanProduct.init(proto:))
            loanProducts = products.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            presentError(error, fallback: "Could not load loan products.")
        }
    }

    func addLoanProduct(_ product: LoanProduct) {
        Task { await create(product) }
    }

    func updateLoanProduct(oldProduct: LoanProduct, newProduct: LoanProduct) {
        Task { await saveUpdate(oldProduct: oldProduct, newProduct: newProduct) }
    }

    func deleteLoanProduct(at indexSet: IndexSet) {
        for index in indexSet {
            let product = filteredProducts[index]
            deleteLoanProduct(product)
        }
    }

    func deleteLoanProduct(_ product: LoanProduct) {
        Task { await delete(product) }
    }

    private func create(_ draft: LoanProduct) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let created = try await loanAPI.createLoanProduct(draft)
            let createdProduct = LoanProduct(proto: created)
            try await loanAPI.upsertEligibility(productID: createdProduct.id, rule: draft.eligibilityRule)
            try await loanAPI.replaceFees(productID: createdProduct.id, fees: draft.fees)
            try await loanAPI.replaceRequiredDocuments(productID: createdProduct.id, documents: draft.requiredDocuments)
            let latest = try await loanAPI.getLoanProduct(productID: createdProduct.id)
            loanProducts.insert(LoanProduct(proto: latest), at: 0)
            actionMessage = "Loan '\(draft.name)' created successfully."
            showActionAlert = true
            showAddLoanSheet = false
        } catch {
            presentError(error, fallback: "Could not create the loan product.")
        }
    }

    private func saveUpdate(oldProduct: LoanProduct, newProduct: LoanProduct) async {
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await loanAPI.updateLoanProduct(newProduct)
            let updatedProduct = LoanProduct(proto: updated)
            try await loanAPI.upsertEligibility(productID: updatedProduct.id, rule: newProduct.eligibilityRule)
            try await loanAPI.replaceFees(productID: updatedProduct.id, fees: newProduct.fees)
            try await loanAPI.replaceRequiredDocuments(productID: updatedProduct.id, documents: newProduct.requiredDocuments)
            let latest = LoanProduct(proto: try await loanAPI.getLoanProduct(productID: updatedProduct.id))
            if let index = loanProducts.firstIndex(where: { $0.id == oldProduct.id }) {
                loanProducts[index] = latest
            }
            actionMessage = "Loan '\(newProduct.name)' updated successfully."
            showActionAlert = true
            editingLoan = nil
        } catch {
            presentError(error, fallback: "Could not update the loan product.")
        }
    }

    private func delete(_ product: LoanProduct) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await loanAPI.deleteLoanProduct(productID: product.id)
            loanProducts.removeAll { $0.id == product.id }
            actionMessage = "Loan '\(product.name)' deleted successfully."
            showActionAlert = true
        } catch {
            presentError(error, fallback: "Could not delete the loan product.")
        }
    }

    private func presentError(_ error: Error, fallback: String) {
        actionMessage = (error as? LocalizedError)?.errorDescription ?? fallback
        showActionAlert = true
    }
}
