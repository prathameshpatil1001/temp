// Views/Login/LoginPasskeyView.swift
// LoanOS — Borrower App
// Login Step 3 — Native passkey verification screen.

import SwiftUI

struct LoginPasskeyView: View {
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 22) {
                headerSection
                verificationCard
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
            Text("Sign in with passkey")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Use the native Apple passkey prompt to continue signing in securely.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var verificationCard: some View {
        VStack(spacing: 18) {
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
                Text(statusTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DS.textPrimary)

                Text(statusSubtitle)
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            if let msg = viewModel.errorMessage {
                Text(msg)
                    .font(.system(size: 14))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
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

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var viewModel: LoginViewModel

    private var actionSection: some View {
        VStack(spacing: 16) {
            PrimaryBtn(
                title: viewModel.isLoading ? viewModel.loadingActionText : "Use Passkey",
                isLoading: viewModel.isLoading,
                disabled: !viewModel.hasWebAuthnRequestOptions && !viewModel.isLoading
            ) {
                Task {
                    let success = await viewModel.verifyPasskey()
                    if success {
                        AnalyticsManager.shared.logEvent(.loginCompleted)
                        session.completeSession(contactIdentifier: viewModel.currentLoginIdentifier)
                    }
                }
            }

            if viewModel.errorMessage != nil {
                Button {
                    if viewModel.allowedFactors.contains("totp") {
                        path.append(LoginRoute.totp)
                    } else {
                        path.append(LoginRoute.mfaSelection)
                    }
                } label: {
                    Text("Use Authenticator App Instead")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DS.primary)
                }
            }
        }
    }

    private var statusTitle: String {
        if viewModel.isLoading {
            return "Waiting for your passkey"
        }
        return "Ready to continue"
    }

    private var statusSubtitle: String {
        if viewModel.isLoading {
            return "Complete the native Face ID or Touch ID prompt on your device."
        }
        return viewModel.hasWebAuthnRequestOptions
            ? "Use your saved passkey on this device to finish signing in."
            : "Passkey options are not available for this session."
    }
}
