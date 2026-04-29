// Views/Signup/SignupPasskeyView.swift
// LoanOS — Borrower App
// Signup Step 4 — Face ID prompt screen.

import SwiftUI

struct SignupPasskeyView: View {
    @Binding var path: NavigationPath

    @State private var appeared = false
    @State private var isEnablingFaceID = false
    @State private var errorMessage = ""

    @EnvironmentObject private var viewModel: SignupViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 22)

            VStack(spacing: 28) {
                Spacer(minLength: 8)

                heroSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.35), value: appeared)

                contentCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 18)
                    .animation(.easeOut(duration: 0.42).delay(0.04), value: appeared)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.75))
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(width: 112, height: 112)

                Image(systemName: "faceid")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(DS.primary)
            }
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)

            VStack(spacing: 8) {
                Text("Enable Face ID")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Turn on Face ID now so this device can offer faster sign in later.")
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }
        }
    }

    private var contentCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("We’ll ask the system to verify your identity now, then continue to authenticator setup.")
                    .font(.system(size: 15))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text("You can skip this for now and enable it later from Settings.")
                    .font(.system(size: 13))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryBtn(
                title: isEnablingFaceID ? "Checking Face ID..." : "Enable Face ID",
                isLoading: isEnablingFaceID
            ) {
                enableFaceID()
            }

            SecondaryBtn(
                title: "Not Now"
            ) {
                QuickLoginPreferencesStore.shared.stageBiometricEnabled(false, for: viewModel.stagedBiometricIdentifiers)
                path.append(SignupRoute.totpPrompt)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(DS.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(22)
        .background(.white.opacity(0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private func enableFaceID() {
        errorMessage = ""
        isEnablingFaceID = true

        BiometricAuth.authenticate(reason: "Verify your identity to enable Face ID for sign in.") { ok, err in
            isEnablingFaceID = false
            if ok {
                QuickLoginPreferencesStore.shared.stageBiometricEnabled(true, for: viewModel.stagedBiometricIdentifiers)
                path.append(SignupRoute.totpPrompt)
            } else {
                errorMessage = BiometricAuth.humanMessage(for: err)
            }
        }
    }
}
