// Views/Signup/SignupOTPView.swift
// LoanOS — Borrower App
// Signup Step 2 — Verify phone number.

import SwiftUI
import Combine

struct SignupOTPView: View {
    @Binding var path: NavigationPath

    @State private var otp = ""
    @State private var appeared = false
    @FocusState private var focused: Bool
    @EnvironmentObject private var viewModel: SignupViewModel

    private var canContinue: Bool {
        otp.count == 6
    }

    private var maskedPhone: String {
        guard let phone = viewModel.signupPhone, phone.count >= 4 else {
            return "your registered phone number"
        }
        let lastFour = String(phone.suffix(4))
        return "+91 ••••••" + lastFour
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
            Text("Verify phone number")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Enter the 6-digit code sent to \(maskedPhone).")
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
            title: "Continue",
            disabled: !canContinue
        ) {
            viewModel.tempPhoneOTP = otp
            path.append(SignupRoute.emailOTP)
        }
    }
}
