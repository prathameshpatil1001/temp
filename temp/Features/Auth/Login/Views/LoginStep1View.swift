// Views/Login/LoginStep1View.swift
// LoanOS — Borrower App
// Login Step 1 — Minimal sign-in screen.

import SwiftUI

fileprivate enum LoginField: Hashable {
    case contact
    case password
}

struct LoginStep1View: View {
    @Binding var path: NavigationPath
    let onGoToSignup: () -> Void
    let onBackToWelcome: () -> Void

    @State private var contact = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @FocusState private var focusedField: LoginField?

    private var canProceed: Bool {
        !contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                BrandBar(onBack: onBackToWelcome)
                    .padding(.bottom, 22)

                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    formSection
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome back")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Sign in with your email or phone number and password.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var formSection: some View {
        VStack(alignment: .center, spacing: 16) {
            LoginSectionCard {
                VStack(spacing: 0) {
                    LoginInputRow(
                        title: "Email or phone",
                        placeholder: "name@example.com",
                        icon: "person.crop.circle",
                        text: $contact,
                        keyboardType: .emailAddress,
                        textContentType: .username,
                        textInputAutocapitalization: .never,
                        submitLabel: .next,
                        isSecure: false,
                        focusedField: $focusedField,
                        field: .contact
                    )

                    Divider()
                        .padding(.leading, 52)

                    LoginInputRow(
                        title: "Password",
                        placeholder: "Enter password",
                        icon: "lock",
                        text: $password,
                        keyboardType: .default,
                        textContentType: .password,
                        textInputAutocapitalization: .never,
                        submitLabel: .done,
                        isSecure: true,
                        focusedField: $focusedField,
                        field: .password
                    )
                }
            }

            if let errorMessage = viewModel.errorMessage {
                InfoCard(icon: "exclamationmark.triangle.fill", color: DS.danger, text: errorMessage)
                    .transition(.opacity)
                    .animation(.easeInOut, value: viewModel.errorMessage)
            }
        }
    }

    @EnvironmentObject private var viewModel: LoginViewModel

    private var actionSection: some View {
        VStack(spacing: 14) {
            PrimaryBtn(
                title: (viewModel.isLoading || isLoggingIn) ? viewModel.loadingActionText : "Continue",
                disabled: !canProceed || viewModel.isLoading || isLoggingIn
            ) {
                focusedField = nil
                isLoggingIn = true
                Task {
                    defer { isLoggingIn = false }
                    let requiresMFA = await viewModel.loginPrimary(identifier: contact, password: password)
                    if requiresMFA {
                        if viewModel.allowedFactors.count > 1 {
                            // Multiple choices — show the picker screen
                            path.append(LoginRoute.mfaSelection)
                        } else if let singleFactor = viewModel.allowedFactors.first {
                            // Single factor — select it automatically
                            let success = await viewModel.selectFactor(factor: singleFactor)
                            if success {
                                switch singleFactor {
                                case "totp":
                                    path.append(LoginRoute.totp)
                                case "webauthn":
                                    path.append(LoginRoute.passkey)
                                default:
                                    // email_otp or phone_otp
                                    path.append(LoginRoute.otp(viewModel.currentChallengeTarget ?? ""))
                                }
                            }
                        }
                    }
                }
            }

            Button {
                onGoToSignup()
            } label: {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(DS.textSecondary)

                    Text("Sign Up")
                        .foregroundColor(DS.primary)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }
}

private struct LoginSectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(.white.opacity(0.84))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }
}

private struct LoginInputRow: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let textInputAutocapitalization: TextInputAutocapitalization
    let submitLabel: SubmitLabel
    let isSecure: Bool
    let focusedField: FocusState<LoginField?>.Binding
    let field: LoginField

    @State private var isPasswordVisible = false

    private var isFocused: Bool {
        focusedField.wrappedValue == field
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(isFocused ? DS.primary : DS.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.textSecondary)

                fieldView
            }

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DS.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(isFocused ? DS.primaryLight.opacity(0.38) : Color.clear)
    }

    @ViewBuilder
    private var fieldView: some View {
        if isSecure {
            if isPasswordVisible {
                TextField(placeholder, text: $text)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(textInputAutocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .focused(focusedField, equals: field)
                    .font(.system(size: 17))
                    .foregroundColor(DS.textPrimary)
            } else {
                SecureField(placeholder, text: $text)
                    .textContentType(textContentType)
                    .submitLabel(submitLabel)
                    .focused(focusedField, equals: field)
                    .font(.system(size: 17))
                    .foregroundColor(DS.textPrimary)
            }
        } else {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .focused(focusedField, equals: field)
                .font(.system(size: 17))
                .foregroundColor(DS.textPrimary)
        }
    }
}
