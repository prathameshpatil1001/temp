// Controllers/SignupFlowController.swift
// LoanOS — Borrower App
// Manages the Signup navigation stack and route definitions.

import SwiftUI

enum SignupRoute: Hashable {
    case phoneOTP
    case emailOTP
    case personalDetails
    case faceIDPrompt
    case totpPrompt
}

struct SignupRoot: View {
    @State private var path = NavigationPath()
    @StateObject private var viewModel = SignupViewModel()
    @StateObject private var kycViewModel = KYCViewModel()
    
    let onBackToLogin: () -> Void
    let onBackToWelcome: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            SignupStep1View(path: $path, onBackToLogin: onBackToLogin, onBackToWelcome: onBackToWelcome)
                .navigationDestination(for: SignupRoute.self) { route in
                    switch route {
                    case .phoneOTP:
                        SignupOTPView(path: $path)

                    case .emailOTP:
                        SignupEmailOTPView(path: $path, onBackToLogin: onBackToLogin)

                    case .personalDetails:
                        BorrowersPersonalDetailsView(path: $path)
                            .environmentObject(kycViewModel)

                    case .faceIDPrompt:
                        SignupPasskeyView(path: $path)

                    case .totpPrompt:
                        SignupTOTPView(path: $path, onBackToLogin: onBackToLogin)
                    }
                }
        }
        .environmentObject(viewModel)
        .tint(DS.primary)
        .alert("Error", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
        .onAppear {
            AnalyticsManager.shared.logEvent(.signupStarted)
        }
    }
}
