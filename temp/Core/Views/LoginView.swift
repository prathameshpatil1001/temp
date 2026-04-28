//
//  LoginView.swift
//  lms_project
//
//  iPad-native login flow: Credentials → MFA Selection → OTP Entry
//

import SwiftUI

// MARK: - Root Login Shell

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            loginBackground

            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Brand panel — landscape iPad only
                    if geo.size.width > 768 {
                        LoginBrandPanel()
                            .frame(width: geo.size.width * 0.40)
                    }

                    // Auth step content
                    loginContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.32), value: authVM.authStep)
    }

    // MARK: - Background

    private var loginBackground: some View {
        ZStack {
            Theme.Colors.adaptiveBackground(colorScheme)
                .ignoresSafeArea()

            Circle()
                .fill(
                    colorScheme == .dark
                    ? AnyShapeStyle(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.10))
                    : AnyShapeStyle(RadialGradient(
                        gradient: Gradient(colors: [
                            Theme.Colors.primary.opacity(0.08),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 360
                    ))
                )
                .frame(width: 600, height: 600)
                .offset(x: -180, y: -180)
                .blur(radius: 40)
                .ignoresSafeArea()
        }
    }

    // MARK: - Step Router

    @ViewBuilder
    private var loginContent: some View {
        switch authVM.authStep {
        case .credentials:
            CredentialsStep()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)),
                    removal:   .opacity.combined(with: .move(edge: .leading))
                ))
        case .mfaSelection:
            MFASelectionStep()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal:   .opacity.combined(with: .move(edge: .leading))
                ))
        case .mfaVerification:
            MFAVerificationStep()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal:   .opacity.combined(with: .move(edge: .leading))
                ))
        case .forcePasswordChange:
            ForcePasswordChangeStep()
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal:   .opacity.combined(with: .move(edge: .leading))
                ))
        case .authenticated:
            Color.clear
        }
    }
}

// MARK: - Brand Panel

private struct LoginBrandPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Theme.Colors.adaptiveBackground(colorScheme) : Color(hex: "0052CC"))
                .overlay {
                    if colorScheme == .dark {
                        Theme.Colors.adaptivePrimary(colorScheme).opacity(0.28)
                    }
                }
                .ignoresSafeArea()

            // Dot grid
            Canvas { ctx, size in
                for i in stride(from: 0, through: Int(size.width), by: 56) {
                    for j in stride(from: 0, through: Int(size.height), by: 56) {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: CGFloat(i), y: CGFloat(j), width: 1.5, height: 1.5)),
                            with: .color(.white.opacity(0.06))
                        )
                    }
                }
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 28)

                // App name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Karz.")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Manage your loans\nlike never before.")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineSpacing(3)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                Spacer()
                Spacer()

                // Feature pills
                VStack(alignment: .leading, spacing: 10) {
                    BrandFeaturePill(icon: "checkmark.shield.fill", text: "Secure Role-Based Access")
                    BrandFeaturePill(icon: "lock.iphone",           text: "Two-Factor Authentication")
                    BrandFeaturePill(icon: "chart.bar.fill",        text: "Real-Time Loan Dashboard")
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)

                Spacer()

                Text("v1.0 · Internal Staff Application")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 52)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.65).delay(0.1)) { appeared = true }
        }
    }
}

private struct BrandFeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Step 1: Credentials

struct CredentialsStep: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var email        = ""
    @State private var password     = ""
    @State private var showPassword = false
    @State private var appeared     = false
    @FocusState private var focus: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.1))
                            .frame(width: 64, height: 64)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                    Text("Karz.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                        .opacity(appeared ? 1 : 0)

                    Text("Sign in to your account")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.bottom, 40)

                // Form card
                VStack(spacing: 0) {
                    LMSInputField(
                        icon: "envelope",
                        placeholder: "Email address",
                        text: $email,
                        keyboardType: .emailAddress,
                        submitLabel: .next
                    ) { focus = .password }
                    .focused($focus, equals: .email)

                    Divider().padding(.leading, 52)

                    LMSSecureField(
                        icon: "lock",
                        placeholder: "Password",
                        text: $password,
                        showPassword: $showPassword,
                        submitLabel: .go
                    ) { submit() }
                    .focused($focus, equals: .password)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.Colors.adaptiveSurface(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // Error
                if let err = authVM.loginError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
                        Text(err).font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.Colors.critical)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let notice = authVM.authNotice {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                        Text(notice).font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.Colors.success)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Sign In button — fixed iPad-appropriate width
                Button(action: submit) {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 280, height: 50)
                        .background(colorScheme == .dark ? Theme.Colors.adaptivePrimary(colorScheme) : Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.05)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { focus = .email }
        }
    }

    private func submit() {
        focus = nil
        authVM.submitCredentials(email: email, password: password)
    }
}

// MARK: - Step 2: MFA Selection

struct MFASelectionStep: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var selected      : MFAMethod = .email
    @State private var appeared      = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 64)

                // Back
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) { authVM.backToCredentials() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                            Text("Back").font(.system(size: 15))
                        }
                        .foregroundStyle(Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 28)

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.1))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                    Text("Two-Factor Verification")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)

                    Text("Choose how to receive your code")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.bottom, 32)

                // Method cards
                VStack(spacing: 12) {
                    ForEach(authVM.availableMFAMethods) { method in
                        MFAMethodCard(method: method, isSelected: selected == method) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selected = method
                            }
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // Receive OTP button — fixed width
                Button {
                    authVM.selectMFA(selected)
                } label: {
                    Text("Receive OTP")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 280, height: 50)
                        .background(colorScheme == .dark ? Theme.Colors.adaptivePrimary(colorScheme) : Theme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            selected = authVM.availableMFAMethods.first ?? .email
            withAnimation(.easeOut(duration: 0.48).delay(0.05)) { appeared = true }
        }
    }
}

private struct MFAMethodCard: View {
    let method: MFAMethod
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? Theme.Colors.primary.opacity(0.12)
                              : Theme.Colors.adaptiveSurfaceSecondary(colorScheme)
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: method.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Theme.Colors.primary : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.Colors.primary : Color.primary)
                    Text(method.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Theme.Colors.primary : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle().fill(Theme.Colors.primary).frame(width: 11, height: 11)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.Colors.adaptiveSurface(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? Theme.Colors.primary.opacity(0.55) : Theme.Colors.adaptiveBorder(colorScheme),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: OTP Entry

struct MFAVerificationStep: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var otp      = ""
    @State private var appeared = false
    @FocusState private var otpFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 64)

                // Back
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) { authVM.backToMFASelection() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                            Text("Back").font(.system(size: 15))
                        }
                        .foregroundStyle(Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 28)

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.1))
                            .frame(width: 64, height: 64)
                        Image(systemName: authVM.selectedMFAMethod == .email
                              ? "envelope.badge.shield.half.filled"
                              : "iphone.and.arrow.forward")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                    Text("Enter Verification Code")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                        .opacity(appeared ? 1 : 0)

                    // Show the masked/target contact returned by backend
                    Group {
                        if !authVM.mfaContact.isEmpty {
                            Text("Code sent to \(authVM.mfaContact)")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Enter any 6-digit code to continue")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 36)

                // OTP boxes
                VStack(spacing: 14) {
                    OTPBoxesView(otp: $otp)
                        .focused($otpFocused)

                    if let err = authVM.otpError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
                            Text(err).font(.system(size: 13))
                        }
                        .foregroundStyle(Theme.Colors.critical)
                        .transition(.opacity)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // Verify button — fixed width
                Button {
                    authVM.verifyOTP(otp)
                } label: {
                    Text("Verify & Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 280, height: 50)
                        .background(otp.count >= 6
                            ? (colorScheme == .dark ? Theme.Colors.adaptivePrimary(colorScheme) : Theme.Colors.primary)
                            : Color.secondary.opacity(0.35)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(otp.count < 6)
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)

                // Resend
                Button {
                    otp = ""
                    authVM.resendOTP()
                } label: {
                    Text("Didn't receive a code? **Resend**")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.48).delay(0.05)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { otpFocused = true }
        }
        .onChange(of: otp) { _, newValue in
            if newValue.count == 6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    authVM.verifyOTP(newValue)
                }
            }
        }
    }
}

// MARK: - Step 4: Forced Password Change

struct ForcePasswordChangeStep: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.warning.opacity(0.14))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Theme.Colors.warning)
                    }
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                    Text("Password Update Required")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)

                    Text("For security, you must set a new password before continuing.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.bottom, 32)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                            .padding(.leading, 16)

                        Group {
                            if showNewPassword {
                                TextField("New password", text: $newPassword)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("New password", text: $newPassword)
                            }
                        }
                        .font(.system(size: 16))
                        .padding(.vertical, 16)

                        Button {
                            showNewPassword.toggle()
                        } label: {
                            Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 14)
                    }

                    Divider().padding(.leading, 52)

                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                            .padding(.leading, 16)

                        Group {
                            if showConfirmPassword {
                                TextField("Confirm new password", text: $confirmPassword)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("Confirm new password", text: $confirmPassword)
                            }
                        }
                        .font(.system(size: 16))
                        .padding(.vertical, 16)

                        Button {
                            showConfirmPassword.toggle()
                        } label: {
                            Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 14)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.Colors.adaptiveSurface(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                if let err = authVM.passwordChangeError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
                        Text(err).font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.Colors.critical)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    authVM.submitForcedPasswordChange(newPassword: newPassword, confirmPassword: confirmPassword)
                } label: {
                    Group {
                        if authVM.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text("Change Password")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 280, height: 50)
                    .background(colorScheme == .dark ? Theme.Colors.adaptivePrimary(colorScheme) : Theme.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(authVM.isLoading)
                .padding(.top, 20)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.48).delay(0.05)) { appeared = true }
        }
    }
}

// MARK: - OTP Boxes

private struct OTPBoxesView: View {
    @Binding var otp: String
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Hidden capture field
            TextField("", text: Binding(
                get: { otp },
                set: { newVal in
                    let filtered = newVal.filter { $0.isNumber }
                    otp = String(filtered.prefix(6))
                }
            ))
            .keyboardType(.numberPad)
            .focused($isFocused)
            .opacity(0.01)
            .frame(width: 1, height: 1)

            // Visual digit boxes
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    let char: String = {
                        guard index < otp.count else { return "" }
                        return String(otp[otp.index(otp.startIndex, offsetBy: index)])
                    }()
                    let isActive = (index == otp.count) && isFocused

                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Theme.Colors.adaptiveSurface(colorScheme))
                        RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(
                                isActive
                                    ? Theme.Colors.primary
                                    : (char.isEmpty ? Color.secondary.opacity(0.2) : Theme.Colors.primary.opacity(0.45)),
                                lineWidth: isActive ? 2 : 1
                            )

                        Text(char)
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)

                        if isActive && char.isEmpty {
                            Rectangle()
                                .fill(Theme.Colors.primary)
                                .frame(width: 2, height: 22)
                        }
                    }
                    .frame(width: 48, height: 56)
                    .animation(.easeInOut(duration: 0.13), value: char)
                }
            }
            .onTapGesture { isFocused = true }
        }
    }
}

// MARK: - Shared Input Field

struct LMSInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel     = .done
    var onSubmit: (() -> Void)?      = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .padding(.leading, 16)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
                .padding(.vertical, 16)
        }
    }
}

// MARK: - Shared Secure Field

struct LMSSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .padding(.leading, 16)

            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                } else {
                    SecureField(placeholder, text: $text)
                        .submitLabel(submitLabel)
                        .onSubmit { onSubmit?() }
                }
            }
            .font(.system(size: 16))
            .padding(.vertical, 16)

            Button { showPassword.toggle() } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
    }
}
