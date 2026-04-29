import Foundation

struct RazorpayPaymentOrder: Hashable {
    let loanId: String
    let emiScheduleId: String
    let orderId: String
    let amount: String
    let currency: String
}

struct RazorpayPaymentVerificationResult {
    let success: Bool
    let payment: LoanPayment?
}
