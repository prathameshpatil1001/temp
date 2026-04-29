// Views/Signup/SignupStep1View.swift
// LoanOS — Borrower App
// Signup Step 1 — Minimal signup screen with input restrictions.

import SwiftUI

fileprivate enum SignupField: Hashable {
    case fullName
    case email
    case phoneNumber
    case password
}

struct SignupStep1View: View {
    @Binding var path: NavigationPath
    let onBackToLogin: () -> Void
    let onBackToWelcome: () -> Void

    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @FocusState private var focusedField: SignupField?

    private var trimmedName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        !trimmedName.isEmpty &&
        trimmedName.range(of: "^[A-Za-z ]+$", options: .regularExpression) != nil
    }

    private var isEmailValid: Bool {
        trimmedEmail.range(
            of: "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$",
            options: .regularExpression
        ) != nil
    }

    private var isPhoneValid: Bool {
        phoneNumber.count == 10
    }

    private var isPasswordValid: Bool {
        !password.isEmpty
    }

    private var canProceed: Bool {
        isNameValid && isEmailValid && isPhoneValid && isPasswordValid
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
        .onChange(of: fullName) { _, newValue in
            let filtered = newValue.filter { $0.isLetter || $0.isWhitespace }
            if filtered != newValue {
                fullName = filtered
            }
        }
        .onChange(of: phoneNumber) { _, newValue in
            let filtered = String(newValue.filter(\.isNumber).prefix(10))
            if filtered != newValue {
                phoneNumber = filtered
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create account")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Enter your name, email, phone number, and password to continue.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SignupSectionCard {
                VStack(spacing: 0) {
                    SignupInputRow(
                        title: "Full name",
                        placeholder: "Enter full name",
                        icon: "person.crop.circle",
                        text: $fullName,
                        keyboardType: .default,
                        textContentType: .name,
                        textInputAutocapitalization: .words,
                        submitLabel: .next,
                        isSecure: false,
                        focusedField: $focusedField,
                        field: .fullName
                    )

                    Divider().padding(.leading, 52)

                    SignupInputRow(
                        title: "Email",
                        placeholder: "name@example.com",
                        icon: "envelope",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        textInputAutocapitalization: .never,
                        submitLabel: .next,
                        isSecure: false,
                        focusedField: $focusedField,
                        field: .email
                    )

                    Divider().padding(.leading, 52)

                    SignupInputRow(
                        title: "Phone number",
                        placeholder: "10-digit mobile number",
                        icon: "phone",
                        text: $phoneNumber,
                        keyboardType: .numberPad,
                        textContentType: .telephoneNumber,
                        textInputAutocapitalization: .never,
                        submitLabel: .next,
                        isSecure: false,
                        focusedField: $focusedField,
                        field: .phoneNumber
                    )

                    Divider().padding(.leading, 52)

                    SignupInputRow(
                        title: "Password",
                        placeholder: "Create password",
                        icon: "lock",
                        text: $password,
                        keyboardType: .default,
                        textContentType: .newPassword,
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
            } else {
                Text(helperText)
                    .font(.system(size: 13))
                    .foregroundColor(helperColor)
            }
        }
    }

    @EnvironmentObject private var viewModel: SignupViewModel

    private var actionSection: some View {
        VStack(spacing: 14) {
            PrimaryBtn(
                title: viewModel.isLoading ? viewModel.loadingActionText : "Continue",
                disabled: !canProceed || viewModel.isLoading
            ) {
                focusedField = nil
                Task {
                    let success = await viewModel.initiateSignup(
                        fullName: trimmedName,
                        email: trimmedEmail,
                        phone: phoneNumber,
                        password: password
                    )
                    if success {
                        path.append(SignupRoute.phoneOTP)
                    }
                }
            }

            Button {
                onBackToLogin()
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(DS.textSecondary)
                    Text("Sign In")
                        .foregroundColor(DS.primary)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }

    private var helperText: String {
        if !trimmedName.isEmpty && !isNameValid {
            return "Name can contain letters and spaces only."
        }
        if !trimmedEmail.isEmpty && !isEmailValid {
            return "Enter a valid email address with a domain."
        }
        if !phoneNumber.isEmpty && !isPhoneValid {
            return "Phone number must be exactly 10 digits."
        }
        return "Name uses letters only. Email must be valid. Phone number must be 10 digits."
    }

    private var helperColor: Color {
        if (!trimmedName.isEmpty && !isNameValid) ||
            (!trimmedEmail.isEmpty && !isEmailValid) ||
            (!phoneNumber.isEmpty && !isPhoneValid) {
            return DS.danger
        }
        return DS.textSecondary
    }
}

private struct SignupSectionCard<Content: View>: View {
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

private struct SignupInputRow: View {
    let title: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let textInputAutocapitalization: TextInputAutocapitalization
    let submitLabel: SubmitLabel
    let isSecure: Bool
    let focusedField: FocusState<SignupField?>.Binding
    let field: SignupField

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
