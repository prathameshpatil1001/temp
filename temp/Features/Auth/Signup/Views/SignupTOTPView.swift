// Views/Signup/SignupTOTPView.swift
// LoanOS — Borrower App
// Signup Step 5 — Authenticator guidance before returning to login.

import SwiftUI

struct SignupTOTPView: View {
    @Binding var path: NavigationPath
    let onBackToLogin: () -> Void

    @State private var appeared = false

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

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundColor(DS.primary)
            }
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 8)

            VStack(spacing: 8) {
                Text("Set up authenticator next")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Your account is ready. Sign in now to finish authenticator setup from inside the app.")
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
                Text("Authenticator enrollment needs an authenticated session.")
                    .font(.system(size: 15))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text("After you sign in, open Settings and enable the authenticator from the security section.")
                    .font(.system(size: 13))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryBtn(
                title: "Continue to Sign In"
            ) {
                onBackToLogin()
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
}
