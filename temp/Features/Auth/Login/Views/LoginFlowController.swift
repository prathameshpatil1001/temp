// Controllers/LoginFlowController.swift
// LoanOS — Borrower App
// Manages the Login navigation stack and route definitions.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Login Routes
// ═══════════════════════════════════════════════════════════════

enum LoginRoute: Hashable { 
    case mfaSelection
    case otp(String) // Pass backend factor target indicator (e.g. email or phone)
    case passkey
    case totp
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Login Flow Controller
// ═══════════════════════════════════════════════════════════════

/// Owns the NavigationStack for the entire login flow.
/// Routes: Email+Password → Factor Select (if multiple) → OTP / TOTP → Home
@MainActor
struct LoginRoot: View {
    @State private var path = NavigationPath()
    @StateObject private var viewModel = LoginViewModel()
    
    let onGoToSignup: () -> Void
    let onBackToWelcome: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            LoginStep1View(path: $path, onGoToSignup: onGoToSignup, onBackToWelcome: onBackToWelcome)
                .navigationDestination(for: LoginRoute.self) { route in
                    switch route {
                    case .mfaSelection:
                        LoginMFAPickerView(path: $path)
                    case .otp(let target):     
                        LoginOTPView(path: $path, factorTarget: target)
                    case .passkey:
                        LoginPasskeyView(path: $path)
                    case .totp:    
                        LoginTOTPView(path: $path)
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
            AnalyticsManager.shared.logEvent(.loginStarted)
        }
    }
}
