import Foundation
import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class DiscoverViewModel: ObservableObject {
    @Published var products: [LoanProduct] = []
    @Published var selectedProduct: LoanProduct? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func fetchProducts() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                products = try await service.listLoanProducts(limit: 20, offset: 0)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load products"
            }
            isLoading = false
        }
    }

    func selectProduct(_ product: LoanProduct) {
        selectedProduct = product
    }

    func amountRange(for product: LoanProduct) -> String {
        "\(formatCurrency(product.minAmount)) – \(formatCurrency(product.maxAmount))"
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let num = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: num)) ?? raw
    }
}
