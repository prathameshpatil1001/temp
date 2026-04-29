import SwiftUI
import Combine

@available(iOS 18.0, *)
struct PaymentCheckoutView: View {
    let loanId: String
    let emiScheduleId: String
    let amount: Double
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = RazorpayPaymentViewModel()
    @State private var selectedMethod: String = "Google Pay"
    @State private var showRazorpayCheckout = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {

                    // Amount Header
                    VStack(spacing: 8) {
                        Text("Amount to Pay")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("₹\(amount.formatted(.number.grouping(.automatic)))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 30)

                    orderStatusCard

                    // Payment Method Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preferred Method")
                            .font(.headline)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            PaymentMethodRow(title: "Google Pay", icon: "g.circle.fill", isSelected: selectedMethod == "Google Pay") { selectedMethod = "Google Pay" }
                            Divider().padding(.leading, 60)
                            PaymentMethodRow(title: "PhonePe", icon: "p.circle.fill", isSelected: selectedMethod == "PhonePe") { selectedMethod = "PhonePe" }
                            Divider().padding(.leading, 60)
                            PaymentMethodRow(title: "Other UPI ID", icon: "link.circle.fill", isSelected: selectedMethod == "Other UPI ID") { selectedMethod = "Other UPI ID" }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        Text("Net Banking & Cards")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                        VStack(spacing: 0) {
                            PaymentMethodRow(title: "Debit Card", icon: "creditcard.fill", isSelected: selectedMethod == "Debit Card") { selectedMethod = "Debit Card" }
                            Divider().padding(.leading, 60)
                            PaymentMethodRow(title: "Net Banking", icon: "building.columns.fill", isSelected: selectedMethod == "Net Banking") { selectedMethod = "Net Banking" }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }

                    launchInstructionsSection

                    Spacer().frame(height: 100)
                }
            }

            // Sticky Bottom Button
            VStack {
                Divider()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.alertRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                Button {
                    showRazorpayCheckout = true
                } label: {
                    HStack {
                        if viewModel.isBusy {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.trailing, 8)
                        }
                        Text(viewModel.isPreparingOrder ? "Preparing…" : "Pay Now")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canLaunchCheckout ? DS.primary : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canLaunchCheckout)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.prepareCheckout(
                loanId: loanId,
                emiScheduleId: emiScheduleId,
                amount: amount
            )
        }
        .sheet(isPresented: $showRazorpayCheckout) {
            if let checkoutRequest = checkoutRequest {
                RazorpayCheckoutWebView(
                    request: checkoutRequest,
                    onSuccess: { result in
                        showRazorpayCheckout = false
                        Task {
                            if let payment = await viewModel.verifyPayment(
                                razorpayPaymentId: result.paymentID,
                                razorpaySignature: result.signature
                            ) {
                                router.push(.paymentSuccess(transactionID: payment.externalTransactionId))
                            }
                        }
                    },
                    onFailure: { message in
                        showRazorpayCheckout = false
                        viewModel.setCheckoutError(message)
                    },
                    onDismiss: {
                        showRazorpayCheckout = false
                    }
                )
                .ignoresSafeArea()
            } else {
                Color.clear
            }
        }
    }

    private var canLaunchCheckout: Bool {
        viewModel.paymentOrder != nil &&
        !viewModel.isBusy
    }

    private var checkoutRequest: RazorpayCheckoutRequest? {
        guard let order = viewModel.paymentOrder else { return nil }

        let name = session.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = session.userEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let contact = session.userPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountInPaise = Int(((Double(order.amount) ?? amount) * 100).rounded())

        return RazorpayCheckoutRequest(
            keyID: RazorpayCheckoutConfig.keyID,
            orderID: order.orderId,
            amountInPaise: amountInPaise,
            currency: order.currency,
            name: name.isEmpty ? "Borrower" : name,
            email: email,
            contact: contact,
            description: RazorpayCheckoutConfig.description
        )
    }

//    private var orderStatusCard: some View {
//        VStack(alignment: .leading, spacing: 14) {
//            Text("Razorpay Order")
//                .font(.headline)
//
//            if viewModel.isPreparingOrder {
//                HStack(spacing: 10) {
//                    ProgressView()
//                    Text("Creating Razorpay order with the backend…")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//            } else if let order = viewModel.paymentOrder {
//                orderDetailRow(title: "Order ID", value: order.orderId)
//                orderDetailRow(title: "Currency", value: order.currency)
//                orderDetailRow(title: "Amount", value: "₹\(order.amount)")
//                orderDetailRow(title: "Key ID", value: RazorpayCheckoutConfig.keyID)
//
//                Text("Your EMI payment order is ready. Tap the button below to open Razorpay checkout and complete the payment inside the borrower app.")
//                    .font(.footnote)
//                    .foregroundColor(.secondary)
//                    .fixedSize(horizontal: false, vertical: true)
//
//                Button {
//                    Task {
//                        await viewModel.retryCheckout(
//                            loanId: loanId,
//                            emiScheduleId: emiScheduleId,
//                            amount: amount
//                        )
//                    }
//                } label: {
//                    Text("Regenerate Order")
//                        .font(.subheadline.weight(.semibold))
//                        .foregroundColor(.mainBlue)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 12)
//                        .background(DS.primaryLight.opacity(0.5))
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                }
//            } else {
//                Text("We couldn't create a Razorpay order yet. Retry to continue.")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//
//                Button {
//                    Task {
//                        await viewModel.retryCheckout(
//                            loanId: loanId,
//                            emiScheduleId: emiScheduleId,
//                            amount: amount
//                        )
//                    }
//                } label: {
//                    Text("Retry Order Creation")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 14)
//                        .background(DS.primary)
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                }
//            }
//        }
//        .padding(20)
//        .background(Color.white)
//        .clipShape(RoundedRectangle(cornerRadius: 16))
//        .padding(.horizontal, 20)
//    }

//    private var launchInstructionsSection: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            Text("Checkout Flow")
//                .font(.headline)
//                .padding(.horizontal, 20)
//
//            VStack(alignment: .leading, spacing: 14) {
//                Text("The borrower app now opens Razorpay checkout using your live order ID and test key. Once the gateway returns the payment ID and signature, the app verifies them with the backend automatically.")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//                    .fixedSize(horizontal: false, vertical: true)
//
//                Text("Selected method: \(selectedMethod)")
//                    .font(.caption.weight(.semibold))
//                    .foregroundColor(.mainBlue)
//
//                Text("If the payment service on the backend has not been deployed yet, order creation will fail before checkout opens.")
//                    .font(.footnote)
//                    .foregroundColor(.orange)
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//            .padding(20)
//            .background(Color.white)
//            .clipShape(RoundedRectangle(cornerRadius: 16))
//            .padding(.horizontal, 20)
//        }
//    }

    private func orderDetailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.subheadline.monospaced())
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Payment Method Row

struct PaymentMethodRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.mainBlue)
                    .frame(width: 32)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.mainBlue)
                        .font(.title3)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(16)
        }
    }
}
