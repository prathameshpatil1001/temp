import Foundation
import Combine

@MainActor
@available(iOS 18.0, *)
final class RazorpayPaymentViewModel: ObservableObject {
    @Published private(set) var paymentOrder: RazorpayPaymentOrder?
    @Published private(set) var completedPayment: LoanPayment?
    @Published private(set) var isPreparingOrder = false
    @Published private(set) var isVerifyingPayment = false
    @Published private(set) var errorMessage: String?

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    var isBusy: Bool {
        isPreparingOrder || isVerifyingPayment
    }

    func prepareCheckout(
        loanId: String,
        emiScheduleId: String,
        amount: Double
    ) async {
        guard paymentOrder == nil else { return }

        isPreparingOrder = true
        errorMessage = nil
        defer { isPreparingOrder = false }

        do {
            paymentOrder = try await service.initiatePayment(
                loanId: loanId,
                emiScheduleId: emiScheduleId,
                amount: Self.amountString(from: amount)
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to create Razorpay order."
        }
    }

    func retryCheckout(
        loanId: String,
        emiScheduleId: String,
        amount: Double
    ) async {
        paymentOrder = nil
        await prepareCheckout(loanId: loanId, emiScheduleId: emiScheduleId, amount: amount)
    }

    func verifyPayment(
        razorpayPaymentId: String,
        razorpaySignature: String
    ) async -> LoanPayment? {
        guard let paymentOrder else {
            errorMessage = "Create the Razorpay order before verifying the payment."
            return nil
        }

        isVerifyingPayment = true
        errorMessage = nil
        defer { isVerifyingPayment = false }

        do {
            let result = try await service.verifyPayment(
                razorpayOrderId: paymentOrder.orderId,
                razorpayPaymentId: razorpayPaymentId,
                razorpaySignature: razorpaySignature
            )
            guard result.success, let payment = result.payment else {
                errorMessage = "Payment verification did not return a successful payment record."
                return nil
            }
            completedPayment = payment
            return payment
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Payment verification failed."
            return nil
        }
    }

    func setCheckoutError(_ message: String) {
        errorMessage = message
    }

    private static func amountString(from amount: Double) -> String {
        if amount.rounded() == amount {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }
}
