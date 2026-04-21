// Views/Login/LoginOTPView.swift
// LoanOS — Borrower App
// Login Step 2 — Minimal OTP verification screen.

import SwiftUI
import Combine

struct LoginOTPView: View {
    @Binding var path: NavigationPath
    let factorTarget: String

    @EnvironmentObject private var viewModel: LoginViewModel
    @EnvironmentObject private var session: SessionStore

    @State private var otp = ""
    @FocusState private var focused: Bool
    @State private var timeRemaining = 30
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var canContinue: Bool {
        otp.count == 6
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 22) {
                headerSection
                otpCard
                actionSection

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
            Text("Enter verification code")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Enter the 6-digit code sent to your registered contact.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var otpFactors: [String] {
        viewModel.allowedFactors.filter { $0.hasSuffix("_otp") }
    }

    private var activeFactorTarget: String {
        guard let factor = viewModel.selectedFactorType else { return "Unknown target" }
        return viewModel.currentChallengeTarget ?? (factor == "email_otp" ? "your email" : "your phone")
    }

    private var otpCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            
            // Inline factor selector if there are multiple OTP factors
            if otpFactors.count > 1 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select where to send your code")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DS.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(otpFactors, id: \.self) { factor in
                            Button {
                                focused = false
                                Task {
                                    _ = await viewModel.selectFactor(factor: factor)
                                    otp = ""
                                    focused = true
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: factor == "email_otp" ? "envelope.fill" : "message.fill")
                                    Text(factor == "email_otp" ? "Email" : "SMS")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(viewModel.selectedFactorType == factor ? DS.primary : Color.clear)
                                .foregroundColor(viewModel.selectedFactorType == factor ? .white : DS.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(viewModel.selectedFactorType == factor ? .clear : DS.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                }
                .padding(.bottom, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("One-time code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.textSecondary)

                Text("Code sent to \(activeFactorTarget)")
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
            }

            if viewModel.selectedFactorType == nil {
                InfoCard(
                    icon: "exclamationmark.circle",
                    color: DS.warning,
                    text: "No verification method selected. Please go back and try again."
                )
            }

            OTPBoxRow(otp: $otp, focused: $focused)
                .disabled(viewModel.isLoading || viewModel.selectedFactorType == nil)
                .opacity(viewModel.selectedFactorType == nil ? 0.5 : 1)

            Button {
                guard !viewModel.isLoading, let factor = viewModel.selectedFactorType, timeRemaining == 0 else { return }
                otp = ""
                focused = true
                timeRemaining = 30
                Task {
                    _ = await viewModel.selectFactor(factor: factor) // this resends the code in login flow
                }
            } label: {
                Text(timeRemaining > 0 ? "Resend code in \(timeRemaining)s" : "Resend code")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(timeRemaining > 0 || viewModel.selectedFactorType == nil ? DS.textSecondary : DS.primary)
            }
            .disabled(viewModel.selectedFactorType == nil || timeRemaining > 0)
            .onReceive(timer) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                }
            }
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
    }

    @State private var isVerifying = false

    private var actionSection: some View {
        VStack(spacing: 16) {
            PrimaryBtn(
                title: viewModel.isLoading || isVerifying ? viewModel.loadingActionText : "Verify",
                disabled: !canContinue || viewModel.isLoading || isVerifying
            ) {
                focused = false
                isVerifying = true
                Task {
                    if await viewModel.verifyMFA(code: otp) {
                        AnalyticsManager.shared.logEvent(.loginCompleted)
                        session.completeSession(contactIdentifier: viewModel.currentLoginIdentifier)
                    }
                    isVerifying = false
                }
            }

            if viewModel.allowedFactors.count > 1 {
                Button {
                    while path.count > 1 {
                        path.removeLast()
                    }
                } label: {
                    Text("Try another method")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DS.primary)
                }
            }
        }
    }
}
