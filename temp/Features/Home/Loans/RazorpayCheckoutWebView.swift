import SwiftUI
import WebKit

struct RazorpayCheckoutRequest {
    let keyID: String
    let orderID: String
    let amountInPaise: Int
    let currency: String
    let name: String
    let email: String
    let contact: String
    let description: String
}

struct RazorpayCheckoutResult {
    let paymentID: String
    let orderID: String
    let signature: String
}

private enum RazorpayCheckoutMessage: String {
    case success = "razorpaySuccess"
    case failure = "razorpayFailure"
    case dismissed = "razorpayDismissed"
}

@available(iOS 18.0, *)
struct RazorpayCheckoutWebView: UIViewRepresentable {
    let request: RazorpayCheckoutRequest
    let onSuccess: (RazorpayCheckoutResult) -> Void
    let onFailure: (String) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess, onFailure: onFailure, onDismiss: onDismiss)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: RazorpayCheckoutMessage.success.rawValue)
        controller.add(context.coordinator, name: RazorpayCheckoutMessage.failure.rawValue)
        controller.add(context.coordinator, name: RazorpayCheckoutMessage.dismissed.rawValue)

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.loadHTMLString(makeHTML(), baseURL: URL(string: "https://checkout.razorpay.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func makeHTML() -> String {
        let escapedName = jsEscape(request.name)
        let escapedEmail = jsEscape(request.email)
        let escapedContact = jsEscape(request.contact)
        let escapedDescription = jsEscape(request.description)
        let escapedOrderID = jsEscape(request.orderID)
        let escapedKey = jsEscape(request.keyID)
        let escapedCurrency = jsEscape(request.currency)

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <style>
            body {
              margin: 0;
              font-family: -apple-system, BlinkMacSystemFont, sans-serif;
              background: #f5f7fb;
              color: #1f2937;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
            }
            .card {
              width: min(92vw, 420px);
              background: white;
              border-radius: 24px;
              padding: 28px 24px;
              box-shadow: 0 12px 30px rgba(15, 23, 42, 0.12);
              text-align: center;
            }
            .title {
              font-size: 22px;
              font-weight: 700;
              margin-bottom: 10px;
            }
            .subtitle {
              color: #6b7280;
              font-size: 14px;
              line-height: 1.5;
              margin-bottom: 20px;
            }
            .loader {
              width: 38px;
              height: 38px;
              border-radius: 50%;
              border: 4px solid #dbeafe;
              border-top-color: #2563eb;
              animation: spin 0.8s linear infinite;
              margin: 0 auto 16px auto;
            }
            @keyframes spin {
              to { transform: rotate(360deg); }
            }
          </style>
          <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
        </head>
        <body>
          <div class="card">
            <div class="loader"></div>
            <div class="title">Opening Razorpay</div>
            <div class="subtitle">Securely redirecting you to complete your EMI payment.</div>
          </div>
          <script>
            function post(name, payload) {
              window.webkit.messageHandlers[name].postMessage(payload);
            }

            const options = {
              key: "\(escapedKey)",
              amount: \(request.amountInPaise),
              currency: "\(escapedCurrency)",
              name: "\(escapedName)",
              description: "\(escapedDescription)",
              order_id: "\(escapedOrderID)",
              prefill: {
                name: "\(escapedName)",
                email: "\(escapedEmail)",
                contact: "\(escapedContact)"
              },
              theme: { color: "#2563eb" },
              handler: function (response) {
                post("razorpaySuccess", {
                  paymentId: response.razorpay_payment_id || "",
                  orderId: response.razorpay_order_id || "",
                  signature: response.razorpay_signature || ""
                });
              },
              modal: {
                ondismiss: function () {
                  post("razorpayDismissed", "Razorpay checkout was dismissed.");
                }
              }
            };

            const rzp = new Razorpay(options);
            rzp.on("payment.failed", function (response) {
              const description = response && response.error && response.error.description
                ? response.error.description
                : "Payment failed in Razorpay checkout.";
              post("razorpayFailure", description);
            });

            window.onload = function () {
              rzp.open();
            };
          </script>
        </body>
        </html>
        """
    }

    private func jsEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let onSuccess: (RazorpayCheckoutResult) -> Void
        private let onFailure: (String) -> Void
        private let onDismiss: () -> Void

        init(
            onSuccess: @escaping (RazorpayCheckoutResult) -> Void,
            onFailure: @escaping (String) -> Void,
            onDismiss: @escaping () -> Void
        ) {
            self.onSuccess = onSuccess
            self.onFailure = onFailure
            self.onDismiss = onDismiss
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let name = RazorpayCheckoutMessage(rawValue: message.name) else { return }

            switch name {
            case .success:
                guard
                    let dict = message.body as? [String: Any],
                    let paymentID = dict["paymentId"] as? String,
                    let orderID = dict["orderId"] as? String,
                    let signature = dict["signature"] as? String
                else {
                    onFailure("Razorpay returned an incomplete success response.")
                    return
                }
                onSuccess(
                    RazorpayCheckoutResult(
                        paymentID: paymentID,
                        orderID: orderID,
                        signature: signature
                    )
                )
            case .failure:
                onFailure(message.body as? String ?? "Payment failed in Razorpay checkout.")
            case .dismissed:
                onDismiss()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onFailure(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFailure(error.localizedDescription)
        }
    }
}
