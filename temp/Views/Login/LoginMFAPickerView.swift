// Views/Login/LoginMFAPickerView.swift
// LoanOS — Borrower App
// Login Step 1.5 — Choose MFA Factor.

import SwiftUI

struct LoginMFAPickerView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: LoginViewModel

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 22) {
                headerSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.35), value: appeared)

                optionsList
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.42).delay(0.04), value: appeared)

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
            Text("Verify it's you")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Select how you would like to securely complete your sign in.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var optionsList: some View {
        VStack(spacing: 12) {
            if viewModel.allowedFactors.contains("totp") {
                FactorOptionRow(
                    icon: "checkmark.shield.fill",
                    title: "Authenticator App",
                    subtitle: "Get a code from your authenticator app",
                    isLoading: viewModel.isLoading && viewModel.selectedFactorType == "totp"
                ) {
                    select(factor: "totp")
                }
                .disabled(viewModel.isLoading)
            }

            if viewModel.allowedFactors.contains("webauthn") {
                FactorOptionRow(
                    icon: "faceid",
                    title: "Passkey",
                    subtitle: "Use Face ID or Touch ID on this device",
                    isLoading: viewModel.isLoading && viewModel.selectedFactorType == "webauthn"
                ) {
                    select(factor: "webauthn")
                }
                .disabled(viewModel.isLoading)
            }

            if viewModel.allowedFactors.contains("email_otp") {
                FactorOptionRow(
                    icon: "envelope.fill",
                    title: "Email Verification",
                    subtitle: "Receive a one-time code via email",
                    isLoading: viewModel.isLoading && viewModel.selectedFactorType == "email_otp"
                ) {
                    select(factor: "email_otp")
                }
                .disabled(viewModel.isLoading)
            }

            if viewModel.allowedFactors.contains("phone_otp") {
                FactorOptionRow(
                    icon: "message.fill",
                    title: "SMS Verification",
                    subtitle: "Receive a one-time code via SMS",
                    isLoading: viewModel.isLoading && viewModel.selectedFactorType == "phone_otp"
                ) {
                    select(factor: "phone_otp")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    private func select(factor: String) {
        Task {
            if factor == "totp" {
                let success = await viewModel.selectFactor(factor: factor)
                if success {
                    path.append(LoginRoute.totp)
                }
            } else if factor == "webauthn" {
                let success = await viewModel.selectFactor(factor: factor)
                if success {
                    path.append(LoginRoute.passkey)
                }
            } else {
                let success = await viewModel.selectFactor(factor: factor)
                if success {
                    path.append(LoginRoute.otp(factor))
                }
            }
        }
    }
}

private struct FactorOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(DS.primaryLight.opacity(0.4))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DS.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(DS.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(DS.primary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DS.textSecondary.opacity(0.5))
                }
            }
            .padding(16)
            .background(.white.opacity(0.84))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.92), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(TapScale())
    }
}
