// Views/Signup/SignupEmailOTPView.swift
// LoanOS — Borrower App
// Signup Step 3 — Verify email address.

import SwiftUI
import Combine

struct SignupEmailOTPView: View {
    @Binding var path: NavigationPath
    let onBackToLogin: () -> Void

    @State private var otp = ""
    @State private var appeared = false
    @FocusState private var focused: Bool
    @EnvironmentObject private var viewModel: SignupViewModel
    @EnvironmentObject private var session: SessionStore

    private var canContinue: Bool {
        otp.count == 6
    }

    private var maskedEmail: String {
        guard let email = viewModel.signupEmail, email.contains("@") else {
            return "your registered email"
        }
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return "your registered email" }
        let localPart = String(parts[0])
        let domain = String(parts[1])
        let visible = localPart.count > 2 ? String(localPart.prefix(2)) : String(localPart.first ?? "?")
        let dots = String(repeating: "•", count: max(3, localPart.count - 2))
        return visible + dots + "@" + domain
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 22) {
                headerSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.35), value: appeared)

                otpCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.42).delay(0.04), value: appeared)

                actionSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.48).delay(0.08), value: appeared)

                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .background(
            LinearGradient(
                colors: [Color.white, DS.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focused = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if !path.isEmpty {
                    path.removeLast()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.82))
                        .background(.ultraThinMaterial, in: Circle())

                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                }
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verify email address")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Enter the 6-digit code sent to \(maskedEmail).")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    @State private var timeRemaining = 30
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var otpCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("One-time code")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.textSecondary)

            OTPBoxRow(otp: $otp, focused: $focused, isSecure: true)

            Button {
                guard timeRemaining == 0 else { return }
                otp = ""
                focused = true
                timeRemaining = 30
                Task {
                    await viewModel.resendOTP()
                }
            } label: {
                Text(timeRemaining > 0 ? "Resend code in \(timeRemaining)s" : "Resend code")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(timeRemaining > 0 ? DS.textSecondary : DS.primary)
            }
            .disabled(timeRemaining > 0)
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var actionSection: some View {
        PrimaryBtn(
            title: viewModel.isLoading ? viewModel.loadingActionText : "Verify",
            disabled: !canContinue || viewModel.isLoading
        ) {
            focused = false
            Task {
                guard let phoneOTP = viewModel.tempPhoneOTP else { return }
                let success = await viewModel.verifyOTPs(emailCode: otp, phoneCode: phoneOTP)
                if success {
                    AnalyticsManager.shared.logEvent(.signupCompleted)
                    if viewModel.redirectToLoginAfterSignup {
                        onBackToLogin()
                    } else {
                        session.completeSession(
                            name: viewModel.signupName,
                            email: viewModel.signupEmail,
                            phone: viewModel.signupPhone
                        )
                        session.setOnboardingComplete(false)
                        path.append(SignupRoute.faceIDPrompt)
                    }
                }
            }
        }
    }
}
