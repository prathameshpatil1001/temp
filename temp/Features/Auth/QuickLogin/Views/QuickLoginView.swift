// Views/QuickLogin/QuickLoginView.swift
// LoanOS — Borrower App
// UX-Optimized (NO LOGIC CHANGES)

import SwiftUI

struct QuickLoginView: View {
    @EnvironmentObject var session: SessionStore

    @State private var isAuthenticating = false
    @State private var bioError = ""
    @State private var totpCode = ""
    @State private var otpCode = ""
    @FocusState private var codeFocused: Bool
    @State private var retryCount = 0
    @State private var quickMethod: QuickMethod = .totp
    @Namespace private var animation
    @State private var otpMFASessionID: String?
    @State private var otpChallengeTarget: String?

    private let maxFailedAttempts = 3

    private enum QuickMethod: String, CaseIterable, Identifiable {
        case totp = "Authenticator"
        case phoneOTP = "Phone OTP"
        case emailOTP = "Email OTP"

        var id: String { rawValue }

        var factor: String {
            switch self {
            case .totp: return "totp"
            case .phoneOTP: return "phone_otp"
            case .emailOTP: return "email_otp"
            }
        }
    }

    private var welcomeText: String {
        session.userName.isEmpty ? "Welcome back" : "Welcome back, \(session.userName)"
    }

    private var availableMethods: [QuickMethod] {
        var methods: [QuickMethod] = []
        if session.hasTotp { methods.append(.totp) }
        methods.append(.phoneOTP)
        methods.append(.emailOTP)
        return methods
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            headerSection

            Spacer(minLength: 30)

            methodPicker
                .padding(.horizontal, 24)
                .padding(.bottom, 26)

            quickLoginSection
                .padding(.horizontal, 20)

            Spacer()

            footerSection
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: quickMethod)
        .background(
            LinearGradient(
                colors: [Color.white, DS.surface, DS.surface.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .onAppear {
            if !availableMethods.contains(quickMethod), let first = availableMethods.first {
                quickMethod = first
            }
        }
        .onChange(of: session.hasTotp) { _, _ in
            if !availableMethods.contains(quickMethod), let first = availableMethods.first {
                quickMethod = first
            }
        }
        .onChange(of: quickMethod) { _, _ in
            bioError = ""
            totpCode = ""
            otpCode = ""
            otpMFASessionID = nil
            otpChallengeTarget = nil
        }
    }

    // MARK: HEADER

    private var headerSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(DS.gradient)
                    .frame(width: 78, height: 78)
                    .shadow(color: DS.primary.opacity(0.25), radius: 20, x: 0, y: 10)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text("Karz")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(welcomeText)
                    .font(.system(size: 15))
                    .foregroundColor(DS.textSecondary)
            }
        }
    }

    // MARK: PICKER

    private var methodPicker: some View {
        Picker("Verification Method", selection: $quickMethod) {
            ForEach(availableMethods) { method in
                Text(method.rawValue).tag(method)
            }
        }
        .pickerStyle(.segmented)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.6))
                .background(.ultraThinMaterial)
        )
    }

    private var quickLoginSection: some View {
        switch quickMethod {
        case .totp:
            return AnyView(totpSection)
        case .phoneOTP, .emailOTP:
            return AnyView(otpSection)
        }
    }

    // MARK: TOTP (UNCHANGED FLOW)

    private var totpSection: some View {
        VStack(spacing: 24) {

            VStack(spacing: 16) {
                Text("Enter Authenticator Code")
                    .font(.system(size: 18, weight: .bold))

                Text("Open your authenticator app and enter the 6-digit code.")
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)

                OTPBoxRow(otp: $totpCode, focused: $codeFocused, isSecure: true)
                    .scaleEffect(1.05)
            }
            .padding(22)
            .background(cardBackground)

            errorView

            PrimaryBtn(
                title: isAuthenticating ? "Verifying..." : "Verify",
                disabled: totpCode.count != 6 || isAuthenticating
            ) {
                codeFocused = false
                isAuthenticating = true
                bioError = ""

                Task {
                    guard #available(iOS 18, *) else {
                        bioError = "This feature requires iOS 18 or later."
                        isAuthenticating = false
                        return
                    }
                    do {
                        let success = try await session.verifyQuickReopenMFA(
                            factor: quickMethod.factor,
                            code: totpCode
                        )

                        try? await Task.sleep(nanoseconds: 300_000_000)

                        if !success {
                            if registerFailedAttempt() {
                                bioError = "Invalid authenticator code."
                            }
                        }
                    } catch let error as AuthError {
                        if registerFailedAttempt() {
                            switch error {
                            case .sessionExpired:
                                bioError = "Your session has expired. Please login again."
                            default:
                                bioError = error.localizedDescription
                            }
                        }
                    } catch {
                        if registerFailedAttempt() {
                            bioError = "Invalid code or connection error."
                        }
                    }
                    isAuthenticating = false
                }
            }
            .frame(height: 54)
        }
    }

    // MARK: OTP (FIXED UX FLOW)

    private var otpSection: some View {
        VStack(spacing: 24) {

            // STEP 1 — SEND CODE
            VStack(spacing: 14) {
                Text("Verify with \(quickMethod.rawValue)")
                    .font(.system(size: 18, weight: .bold))

                Text("We’ll send a 6-digit verification code.")
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)

                SecondaryBtn(
                    title: isAuthenticating ? "Sending..." : "Send code"
                ) {
                    codeFocused = false
                    isAuthenticating = true
                    bioError = ""

                    Task {
                        do {
                            let result = try await session.beginQuickReopenOTP(factor: quickMethod.factor)
                            otpMFASessionID = result.mfaSessionID
                            otpChallengeTarget = result.challengeTarget
                            otpCode = ""

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                codeFocused = true
                            }
                        } catch {
                            bioError = error.localizedDescription
                        }
                        isAuthenticating = false
                    }
                }
                .disabled(isAuthenticating)
            }
            .padding(22)
            .background(cardBackground)

            // STEP 2 — INPUT (ONLY AFTER SEND)
            if otpMFASessionID != nil {
                VStack(spacing: 16) {

                    if let target = otpChallengeTarget {
                        Text("Code sent to \(target)")
                            .font(.system(size: 13))
                            .foregroundColor(DS.textSecondary)
                    }

                    OTPBoxRow(otp: $otpCode, focused: $codeFocused, isSecure: true)
                        .scaleEffect(1.05)

                    PrimaryBtn(
                        title: isAuthenticating ? "Verifying..." : "Verify",
                        disabled: otpCode.count != 6 || isAuthenticating
                    ) {
                        codeFocused = false
                        isAuthenticating = true
                        bioError = ""

                        Task {
                            do {
                                guard let mfaSessionID = otpMFASessionID else { return }
                                let success = try await session.verifyQuickReopenOTP(
                                    mfaSessionID: mfaSessionID,
                                    factor: quickMethod.factor,
                                    code: otpCode
                                )

                                if !success, registerFailedAttempt() {
                                    bioError = "Invalid OTP code."
                                }
                            } catch {
                                if registerFailedAttempt() {
                                    bioError = "Invalid OTP or connection error."
                                }
                            }
                            isAuthenticating = false
                        }
                    }
                    .frame(height: 54)
                }
                .padding(22)
                .background(cardBackground)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            errorView
        }
    }

    // MARK: COMPONENTS

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.white.opacity(0.7))
            )
            .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
    }

    private var errorView: some View {
        Group {
            if !bioError.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(bioError)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.2)

            Button {
                session.logout()
            } label: {
                Text("Back to login")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.textSecondary)
            }
        }
    }

    // MARK: LOGIC (UNCHANGED)

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
