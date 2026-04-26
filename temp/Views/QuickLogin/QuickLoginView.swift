// Views/QuickLogin/QuickLoginView.swift
// Direct Sales Team App
// Quick-login screen for returning users.
// Uses InitiateReopen + MFA flow for server-side verification.

import SwiftUI

struct QuickLoginView: View {
    @EnvironmentObject var session: SessionStore

    @State private var isAuthenticating = false
    @State private var bioError = ""
    @State private var showTOTP = false
    @State private var showOTPEntry = false
    @State private var totpCode = ""
    @State private var otpCode = ""
    @State private var otpFactor: String = "email_otp"
    @State private var otpTarget: String = ""
    @State private var mfaSessionID: String = ""
    @FocusState private var totpFocused: Bool
    @FocusState private var otpFocused: Bool
    @State private var retryCount = 0
    @State private var isBiometricQuickLoginEnabled = false
    @State private var isAuthenticatorQuickLoginEnabled = false

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
            } else if showOTPEntry {
                otpSection
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showOTPEntry)
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
                Text("LoanOS")
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
                triggerReopenWithPasskey()
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
                        Text(isAuthenticating ? "Verifying..." : "Use Face ID")
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
                    showOTPEntry = false
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

            Button {
                bioError = ""
                requestOTP(factor: "email_otp")
            } label: {
                Text("Send Email Code")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DS.primary)
                    .padding(.top, 4)
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
                bioError = ""

                Task {
                    do {
                        let success = try await session.verifyQuickReopenMFA(factor: "totp", code: totpCode)
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !success {
                            if registerFailedAttempt() {
                                bioError = "Invalid authenticator code."
                            }
                        }
                    } catch {
                        if registerFailedAttempt() {
                            bioError = error.localizedDescription
                        }
                    }
                    isAuthenticating = false
                }
            }

            if isBiometricQuickLoginEnabled {
                Button {
                    totpCode = ""
                    showTOTP = false
                } label: {
                    Text("Go back to Face ID")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DS.textSecondary)
                }
            }
        }
    }

    private var otpSection: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Verification Code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.textSecondary)

                    Text("Enter the 6-digit code sent to \(otpTarget).")
                        .font(.system(size: 14))
                        .foregroundColor(DS.textSecondary)
                }

                OTPBoxRow(otp: $otpCode, focused: $otpFocused)
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
                disabled: otpCode.count != 6 || isAuthenticating
            ) {
                otpFocused = false
                isAuthenticating = true
                bioError = ""

                Task {
                    do {
                        let success = try await session.verifyQuickReopenOTP(
                            mfaSessionID: mfaSessionID,
                            factor: otpFactor,
                            code: otpCode
                        )
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !success {
                            if registerFailedAttempt() {
                                bioError = "Invalid verification code."
                            }
                        }
                    } catch {
                        if registerFailedAttempt() {
                            bioError = error.localizedDescription
                        }
                    }
                    isAuthenticating = false
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
            isBiometricQuickLoginEnabled = false
            isAuthenticatorQuickLoginEnabled = false
            return
        }

        isBiometricQuickLoginEnabled = QuickLoginPreferencesStore.shared.isBiometricEnabled(for: userID)
        isAuthenticatorQuickLoginEnabled = QuickLoginPreferencesStore.shared.isAuthenticatorEnabled(for: userID)
        showTOTP = !isBiometricQuickLoginEnabled && isAuthenticatorQuickLoginEnabled
    }

    private func requestOTP(factor: String) {
        isAuthenticating = true
        bioError = ""

        Task {
            do {
                let result = try await session.beginQuickReopenOTP(factor: factor)
                mfaSessionID = result.mfaSessionID
                otpFactor = factor
                otpTarget = result.challengeTarget.isEmpty ? (factor == "email_otp" ? "your email" : "your phone") : result.challengeTarget
                otpCode = ""
                showTOTP = false
                showOTPEntry = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    otpFocused = true
                }
            } catch {
                if registerFailedAttempt() {
                    bioError = "Failed to send verification code: \(error.localizedDescription)"
                }
            }
            isAuthenticating = false
        }
    }

    /// Quick-login via passkey: InitiateReopen → selectFactor(webauthn) → beginPasskeyLogin → getAssertion → finishPasskeyLogin.
    /// This provides true server-side authentication backed by WebAuthn.
    private func triggerReopenWithPasskey() {
        bioError = ""
        isAuthenticating = true

        Task {
            do {
                let success = try await session.verifyQuickReopenPasskey()
                if !success {
                    if registerFailedAttempt() {
                        bioError = "Passkey verification failed."
                    }
                }
            } catch let error as AuthError {
                switch error {
                case .deviceMismatch, .sessionExpired:
                    if registerFailedAttempt() {
                        bioError = error.localizedDescription
                    }
                default:
                    if registerFailedAttempt() {
                        bioError = "Authentication failed. Please try again."
                    }
                }
            } catch {
                // PasskeyManager.PasskeyError.cancelled means user cancelled Face ID
                if registerFailedAttempt() {
                    bioError = "Authentication failed. Please try again."
                }
            }
            isAuthenticating = false
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
