// Core/DesignSystem/AppComponents.swift
// LoanOS Borrower App
// Shared reusable visual components used across multiple features.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - Form Components
// ═══════════════════════════════════════════════════════════════

struct AppTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(focused ? DS.primary : DS.textSecondary)
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.2), value: focused)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(DS.textPrimary)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .focused($focused)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(DS.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(focused ? DS.primary : DS.border, lineWidth: focused ? 1.8 : 1)
                .animation(.easeInOut(duration: 0.2), value: focused)
        )
        .shadow(color: focused ? DS.primary.opacity(0.1) : .black.opacity(0.03),
                radius: focused ? 8 : 4, x: 0, y: 2)
    }
}

struct AppSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var revealed = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(focused ? DS.primary : DS.textSecondary)
                .frame(width: 20)

            Group {
                if revealed {
                    TextField(placeholder, text: $text)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.system(size: 16, design: .rounded))
            .foregroundColor(DS.textPrimary)
            .focused($focused)

            Spacer()

            Button {
                revealed.toggle()
            } label: {
                Image(systemName: revealed ? "eye.slash" : "eye")
                    .foregroundColor(DS.textSecondary)
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(DS.card)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(focused ? DS.primary : DS.border, lineWidth: focused ? 1.8 : 1)
                .animation(.easeInOut(duration: 0.2), value: focused)
        )
        .shadow(color: focused ? DS.primary.opacity(0.1) : .black.opacity(0.03),
                radius: focused ? 8 : 4, x: 0, y: 2)
    }
}

// MARK: OTP 6-box

struct OTPBoxRow: View {
    @Binding var otp: String
    @FocusState.Binding var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .focused($focused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: otp) { _, value in
                    otp = String(value.filter(\.isNumber).prefix(6))
                }
                .accessibilityLabel("One-Time Password Code")
                .accessibilityValue(otp.isEmpty ? "Empty" : otp.map { String($0) }.joined(separator: ", "))
                .accessibilityHint("Enter your 6-digit verification code")

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    let character: String = otp.count > index
                        ? String(otp[otp.index(otp.startIndex, offsetBy: index)])
                        : ""

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(character.isEmpty ? DS.card : DS.primaryLight)

                        RoundedRectangle(cornerRadius: 12)
                            .stroke(character.isEmpty ? DS.border : DS.primary,
                                    lineWidth: character.isEmpty ? 1.2 : 2)

                        if character.isEmpty && index == otp.count && focused {
                            Rectangle()
                                .fill(DS.primary)
                                .frame(width: 2, height: 22)
                                .opacity(0.8)
                        } else {
                            Text(character)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(DS.primary)
                        }
                    }
                    .frame(height: 56)
                    .animation(.spring(response: 0.2), value: character)
                }
            }
            .accessibilityHidden(true)
        }
        .onTapGesture {
            focused = true
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Layout / Decoration Components
// ═══════════════════════════════════════════════════════════════

struct ScreenBadge: View {
    let badge: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(badge)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(color.opacity(0.12))
                .cornerRadius(20)

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)
                .lineSpacing(2)

            Text(subtitle)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoCard: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))

            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct BrandBar: View {
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let onBack {
                Button(action: onBack) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.82))
                            .background(.ultraThinMaterial, in: Circle())
                            .frame(width: 38, height: 38)
                            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)

                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DS.textPrimary)
                    }
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DS.gradient)
                    .frame(width: 38, height: 38)

                Image(systemName: "building.columns.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Karz")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)

                Text("Safe Borrowing")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(DS.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct StepBar: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...total, id: \.self) { step in
                    Capsule()
                        .fill(step <= current ? DS.primary : DS.border)
                        .frame(height: 4)
                        .animation(.spring(response: 0.4), value: current)
                }
            }

            HStack {
                Text("Step \(current) of \(total)")
                    .font(.caption)
                    .foregroundColor(DS.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

struct TrustBadge: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(DS.primary)

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DS.textSecondary)
        }
    }
}

//struct FeatureRow: View {
//    let icon: String
//    let text: String
//
//    var body: some View {
//        HStack(spacing: 12) {
//            Image(systemName: icon)
//                .foregroundColor(DS.primary)
//                .font(.system(size: 13, weight: .semibold))
//                .frame(width: 30, height: 30)
//                .background(DS.primaryLight)
//                .cornerRadius(8)
//
//            Text(text)
//                .font(.system(size: 14, design: .rounded))
//                .foregroundColor(DS.textSecondary)
//        }
//    }
//}

struct ConfettiView: View {
    let trigger: Bool

    let items = (0..<24).map { _ in (
        x: CGFloat.random(in: 0.04...0.96),
        y: CGFloat.random(in: 0.0...0.5),
        size: CGFloat.random(in: 7...15),
        color: [Color(hex: "#1A56E8"), Color(hex: "#0ECB7A"),
                Color(hex: "#FFB800"), Color(hex: "#FF4F8B")].randomElement()!,
        rot: Double.random(in: 0...360)
    )}

    var body: some View {
        GeometryReader { geometry in
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]

                RoundedRectangle(cornerRadius: 3)
                    .fill(item.color)
                    .frame(width: item.size, height: item.size * 0.5)
                    .rotationEffect(.degrees(item.rot))
                    .position(
                        x: item.x * geometry.size.width,
                        y: trigger ? item.y * geometry.size.height : -20
                    )
                    .opacity(trigger ? 0.75 : 0)
                    .animation(
                        .spring(response: 0.9, dampingFraction: 0.6)
                            .delay(Double(index) * 0.035),
                        value: trigger
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

struct BiometricCard: View {
    let isAuthenticating: Bool
    let success: Bool
    let failed: Bool
    let errorMessage: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            success ? DS.success.opacity(0.2 - Double(index) * 0.06)
                            : failed ? DS.danger.opacity(0.2 - Double(index) * 0.06)
                            : DS.primary.opacity(0.15 - Double(index) * 0.04),
                            lineWidth: 1.5
                        )
                        .frame(width: CGFloat(80 + index * 28), height: CGFloat(80 + index * 28))
                        .scaleEffect(isAuthenticating ? 1.08 : 1)
                        .animation(
                            .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isAuthenticating
                        )
                }

                Circle()
                    .fill(success ? DS.success.opacity(0.15) : failed ? DS.danger.opacity(0.1) : DS.primaryLight)
                    .frame(width: 90, height: 90)

                Image(systemName: success ? "checkmark.circle.fill" : failed ? "xmark.circle.fill" : "faceid")
                    .font(.system(size: success || failed ? 46 : 44))
                    .foregroundColor(success ? DS.success : failed ? DS.danger : DS.primary)
                    .scaleEffect(success || failed ? 1.1 : 1)
                    .animation(.spring(response: 0.4), value: success)
            }
            .frame(height: 145)

            VStack(spacing: 4) {
                Text(
                    success ? "Identity Verified!"
                    : failed ? "Authentication Failed"
                    : isAuthenticating ? "Verifying…" : "Ready to authenticate"
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(success ? DS.success : failed ? DS.danger : DS.textPrimary)

                Text(
                    success ? "Proceeding to next step"
                    : failed && !errorMessage.isEmpty ? errorMessage
                    : "Tap Continue to trigger Face ID / Touch ID"
                )
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(DS.textSecondary)
                .multilineTextAlignment(.center)
            }
            .animation(.easeInOut(duration: 0.25), value: success)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(DS.card)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.border, lineWidth: 1)
        )
    }
}
