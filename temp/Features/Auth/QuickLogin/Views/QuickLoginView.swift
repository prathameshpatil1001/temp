// Views/QuickLogin/QuickLoginView.swift
// LoanOS — Borrower App
// Minimal quick-login screen for returning users.

import SwiftUI

struct QuickLoginView: View {
    @EnvironmentObject var session: SessionStore

    @State private var isAuthenticating = false
    @State private var bioError = ""
    @State private var showTOTP = false
    @State private var totpCode = ""
    @FocusState private var totpFocused: Bool
    @State private var retryCount = 0
    @State private var isBiometricQuickLoginEnabled = true
    @State private var isAuthenticatorQuickLoginEnabled = true

    private let maxFailedAttempts = 3

    private var welcomeText: String {
        session.userName.isEmpty ? "Welcome back" : "Welcome back, \(session.userName)"
    }

    private var shouldShowTOTPEntry: Bool {
        if !isBiometricQuickLoginEnabled && isAuthenticatorQuickLoginEnabled {
            return true
        }
        return showTOTP
    }

    private var hasAnyQuickLoginMethod: Bool {
        isBiometricQuickLoginEnabled || isAuthenticatorQuickLoginEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            headerSection

            Spacer(minLength: 28)

            if !hasAnyQuickLoginMethod {
                passwordFallbackSection
                    .padding(.horizontal, 20)
            } else if shouldShowTOTPEntry {
                totpSection
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                biometricSection
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            footerSection
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showTOTP)
        .background(
            LinearGradient(
                colors: [Color.white, DS.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .onAppear(perform: refreshQuickLoginPreferences)
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.gradient)
                    .frame(width: 72, height: 72)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("Karz")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)

                Text(welcomeText)
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
            }
        }
    }

    private var biometricSection: some View {
        VStack(spacing: 16) {
            Button {
                triggerFaceID()
            } label: {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.82))
                            .background(.ultraThinMaterial, in: Circle())
                            .frame(width: 112, height: 112)

                        Image(systemName: "faceid")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundColor(DS.primary)
                    }

                    VStack(spacing: 6) {
                        Text(isAuthenticating ? "Checking Face ID" : "Use Face ID")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DS.textPrimary)

                        Text("Sign in securely with biometrics.")
                            .font(.system(size: 14))
                            .foregroundColor(DS.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.white.opacity(0.82))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(TapScale())
            .disabled(isAuthenticating)

            if !bioError.isEmpty {
                Text(bioError)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if isAuthenticatorQuickLoginEnabled {
                Button {
                    bioError = ""
                    showTOTP = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        totpFocused = true
                    }
                } label: {
                    Text("Use Authenticator App")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DS.primary)
                        .padding(.top, 8)
                }
            }
        }
    }

    private var totpSection: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authenticator Code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.textSecondary)

                    Text("Enter the 6-digit code from your app.")
                        .font(.system(size: 14))
                        .foregroundColor(DS.textSecondary)
                }

                OTPBoxRow(otp: $totpCode, focused: $totpFocused)
            }
            .padding(20)
            .background(.white.opacity(0.84))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.92), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
            
            if !bioError.isEmpty {
                Text(bioError)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, -12)
            }

            PrimaryBtn(
                title: isAuthenticating ? "Verifying..." : "Verify",
                disabled: totpCode.count != 6 || isAuthenticating
            ) {
                totpFocused = false
                isAuthenticating = true
                bioError = "" // Re-using bioError as a generic alert if needed
                
                Task {
                    guard #available(iOS 18, *) else {
                        bioError = "This feature requires iOS 18 or later."
                        isAuthenticating = false
                        return
                    }
                    do {
                        let success = try await session.verifyQuickTOTP(code: totpCode)
                        
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        
                        if success {
                            session.unlockAppSession()
                        } else {
                            if registerFailedAttempt() {
                                bioError = "Invalid authenticator code."
                            }
                        }
                    } catch {
                        if registerFailedAttempt() {
                            bioError = "Invalid authenticator code or connection error."
                        }
                    }
                    isAuthenticating = false
                }
            }

            if isBiometricQuickLoginEnabled {
                Button {
                    totpCode = ""
                    bioError = ""
                    showTOTP = false
                } label: {
                    Text("Go back to Face ID")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DS.textSecondary)
                }
            }
        }
    }

    private var passwordFallbackSection: some View {
        VStack(spacing: 18) {
            Text("Quick login is turned off for this account on this device.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DS.textPrimary)
                .multilineTextAlignment(.center)

            Text("Use your password to continue.")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)

            PrimaryBtn(title: "Use Password") {
                session.logout()
            }
        }
        .padding(24)
        .background(.white.opacity(0.84))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var footerSection: some View {
        Button {
            session.logout()
        } label: {
            Text(hasAnyQuickLoginMethod ? "Sign in with a different account" : "Back to login")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)
        }
    }

    private func refreshQuickLoginPreferences() {
        guard let accessToken = try? TokenStore.shared.accessToken(),
              let userID = JWTClaimsDecoder.subject(from: accessToken) else {
            isBiometricQuickLoginEnabled = true
            isAuthenticatorQuickLoginEnabled = true
            return
        }

        isBiometricQuickLoginEnabled = QuickLoginPreferencesStore.shared.isBiometricEnabled(for: userID)
        isAuthenticatorQuickLoginEnabled = QuickLoginPreferencesStore.shared.isAuthenticatorEnabled(for: userID)
        showTOTP = !isBiometricQuickLoginEnabled && isAuthenticatorQuickLoginEnabled
    }

    private func triggerFaceID() {
        bioError = ""
        isAuthenticating = true

        BiometricAuth.authenticate(reason: "Verify your identity to open LoanOS") { ok, err in
            isAuthenticating = false
            if ok {
                session.unlockAppSession()
            } else {
                let message = BiometricAuth.humanMessage(for: err)
                if registerFailedAttempt() {
                    bioError = message
                }
            }
        }
    }

    @discardableResult
    private func registerFailedAttempt() -> Bool {
        retryCount += 1
        if retryCount >= maxFailedAttempts {
            session.logout(reason: "Too many failed quick-login attempts. Please sign in again.")
            return false
        }
        return true
    }
}
