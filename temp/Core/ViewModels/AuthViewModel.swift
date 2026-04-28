//
//  AuthViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - MFA Method

enum MFAMethod: String, CaseIterable, Identifiable {
    case email = "email"
    case sms   = "sms"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .email: return "Email OTP"
        case .sms:   return "SMS OTP"
        }
    }

    var icon: String {
        switch self {
        case .email: return "envelope.badge.shield.half.filled"
        case .sms:   return "iphone.and.arrow.forward"
        }
    }

    var description: String {
        switch self {
        case .email: return "Receive a one-time code by email"
        case .sms:   return "Receive a one-time code by SMS"
        }
    }

    var inputPlaceholder: String {
        switch self {
        case .email: return "Your email address"
        case .sms:   return "Your phone number"
        }
    }

    var inputKeyboardType: UIKeyboardType {
        switch self {
        case .email: return .emailAddress
        case .sms:   return .phonePad
        }
    }

    var backendFactor: String {
        switch self {
        case .email: return "email_otp"
        case .sms:   return "phone_otp"
        }
    }
}

// MARK: - Auth Step

enum AuthStep {
    case credentials       // email + password screen
    case mfaSelection      // choose MFA method
    case mfaVerification   // enter OTP
    case forcePasswordChange
    case authenticated     // logged in
}

// MARK: - AuthViewModel

@MainActor
class AuthViewModel: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false

    // Published session state
    @Published var currentRole: UserRole? = nil
    @Published var currentUser: User?     = nil

    // Auth flow state
    @Published var authStep: AuthStep = .credentials
    @Published var loginError: String? = nil
    @Published var selectedMFAMethod: MFAMethod = .email
    @Published var mfaContact: String = ""   // challenge target from backend
    @Published var otpError: String? = nil
    @Published var passwordChangeError: String? = nil
    @Published var authNotice: String? = nil
    @Published var isLoading: Bool = false

    private let dataService = MockDataService.shared
    private let authAPI = AuthAPI()
    private let sessionStore = SessionStore.shared

    private var mfaSessionID: String = ""
    private var allowedMFAMethods: [MFAMethod] = []
    private var pendingCurrentPassword: String = ""

    var isLoggedIn: Bool { currentRole != nil }
    var availableMFAMethods: [MFAMethod] {
        allowedMFAMethods.isEmpty ? MFAMethod.allCases : allowedMFAMethods
    }

    // MARK: - Step 1: Validate Credentials

    func submitCredentials(email: String, password: String) {
        loginError = nil
        otpError = nil
        passwordChangeError = nil
        authNotice = nil

        let identifier = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !rawPassword.isEmpty else {
            loginError = "Please enter your email and password."
            return
        }

        isLoading = true
        Task {
            do {
                let response = try await authAPI.loginPrimary(emailOrPhone: identifier, password: rawPassword)
                let methods = Self.mapAllowedMethods(response.allowedFactors)
                guard !response.mfaSessionID.isEmpty, !methods.isEmpty else {
                    throw APIError.failedPrecondition("No supported MFA factor available. Use email OTP or phone OTP.")
                }

                mfaSessionID = response.mfaSessionID
                allowedMFAMethods = methods
                selectedMFAMethod = methods.first ?? .email
                pendingCurrentPassword = rawPassword
                authStep = .mfaSelection
            } catch {
                loginError = (error as? LocalizedError)?.errorDescription ?? "Login failed"
            }
            isLoading = false
        }
    }

    // MARK: - Step 2: Select MFA

    func selectMFA(_ method: MFAMethod) {
        guard !mfaSessionID.isEmpty else {
            loginError = "Login session expired. Please sign in again."
            authStep = .credentials
            return
        }
        guard allowedMFAMethods.contains(method) else {
            loginError = "Selected MFA method is not allowed for this account."
            return
        }

        selectedMFAMethod = method
        mfaContact = ""
        loginError = nil
        isLoading = true

        Task {
            do {
                let response = try await authAPI.selectLoginMFAFactor(mfaSessionID: mfaSessionID, factor: method.backendFactor)
                mfaContact = response.challengeTarget
                authStep = .mfaVerification
            } catch {
                loginError = (error as? LocalizedError)?.errorDescription ?? "Failed to send OTP"
            }
            isLoading = false
        }
    }

    // MARK: - Step 3: Verify OTP (dummy — any input accepted)

    func verifyOTP(_ entered: String) {
        otpError = nil

        let code = entered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            otpError = "Please enter the verification code."
            return
        }

        guard !mfaSessionID.isEmpty else {
            otpError = "Login session expired. Please sign in again."
            authStep = .credentials
            return
        }

        isLoading = true
        Task {
            do {
                let tokens = try await authAPI.verifyLoginMFA(
                    mfaSessionID: mfaSessionID,
                    method: selectedMFAMethod,
                    otpCode: code,
                    deviceID: sessionStore.deviceID
                )
                sessionStore.updateTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)

                let profile = try await authAPI.getMyProfile()
                if profile.isRequiringPasswordChange {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        authStep = .forcePasswordChange
                    }
                    return
                }

                guard let mappedRole = Self.mapBackendRole(profile.role) else {
                    throw APIError.permissionDenied("Only admin, manager, and officer roles are supported in this app.")
                }

                withAnimation(.easeInOut(duration: 0.35)) {
                    currentRole = mappedRole
                    currentUser = Self.mapProfileToUser(profile, role: mappedRole)
                    authStep = .authenticated
                }
            } catch {
                otpError = (error as? LocalizedError)?.errorDescription ?? "OTP verification failed"
            }
            isLoading = false
        }
    }

    // MARK: - Resend OTP

    func resendOTP() {
        otpError = nil
        guard !mfaSessionID.isEmpty else {
            otpError = "Login session expired. Please sign in again."
            authStep = .credentials
            return
        }

        isLoading = true
        Task {
            do {
                let response = try await authAPI.selectLoginMFAFactor(mfaSessionID: mfaSessionID, factor: selectedMFAMethod.backendFactor)
                mfaContact = response.challengeTarget
            } catch {
                otpError = (error as? LocalizedError)?.errorDescription ?? "Failed to resend OTP"
            }
            isLoading = false
        }
    }

    // MARK: - Back Navigation

    func backToCredentials() {
        mfaSessionID = ""
        allowedMFAMethods = []
        mfaContact  = ""
        pendingCurrentPassword = ""
        loginError  = nil
        otpError    = nil
        passwordChangeError = nil
        authNotice = nil
        authStep    = .credentials
    }

    func backToMFASelection() {
        otpError = nil
        authStep = .mfaSelection
    }

    // MARK: - Logout

    func logout() {
        let access = sessionStore.accessToken
        let refresh = sessionStore.refreshToken

        Task {
            if !access.isEmpty || !refresh.isEmpty {
                _ = try? await authAPI.logout(accessToken: access, refreshToken: refresh)
            }

            sessionStore.clear()
            withAnimation(.easeInOut(duration: 0.3)) {
                currentRole       = nil
                currentUser       = nil
                mfaSessionID      = ""
                allowedMFAMethods = []
                mfaContact        = ""
                pendingCurrentPassword = ""
                loginError        = nil
                otpError          = nil
                passwordChangeError = nil
                authNotice = nil
                authStep          = .credentials
            }
        }
    }

    func submitForcedPasswordChange(newPassword: String, confirmPassword: String) {
        passwordChangeError = nil
        authNotice = nil

        let trimmedNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedNew.isEmpty, !trimmedConfirm.isEmpty else {
            passwordChangeError = "Please enter and confirm your new password."
            return
        }

        guard trimmedNew == trimmedConfirm else {
            passwordChangeError = "New password and confirmation do not match."
            return
        }

        guard !pendingCurrentPassword.isEmpty else {
            passwordChangeError = "Session expired. Please sign in again."
            authStep = .credentials
            return
        }

        isLoading = true
        Task {
            do {
                let response = try await authAPI.changePassword(
                    currentPassword: pendingCurrentPassword,
                    newPassword: trimmedNew
                )

                if !response.success {
                    throw APIError.unknown("Password change was not accepted. Please try again.")
                }

                let access = sessionStore.accessToken
                let refresh = sessionStore.refreshToken
                if !access.isEmpty || !refresh.isEmpty {
                    _ = try? await authAPI.logout(accessToken: access, refreshToken: refresh)
                }

                sessionStore.clear()
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentRole = nil
                    currentUser = nil
                    mfaSessionID = ""
                    allowedMFAMethods = []
                    mfaContact = ""
                    pendingCurrentPassword = ""
                    loginError = nil
                    otpError = nil
                    passwordChangeError = nil
                    authNotice = "Password changed successfully. Please sign in again."
                    authStep = .credentials
                }
            } catch {
                passwordChangeError = (error as? LocalizedError)?.errorDescription ?? "Failed to change password"
            }
            isLoading = false
        }
    }

    // MARK: - Legacy shim

    func login(as role: UserRole) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentRole = role
            currentUser = dataService.currentUser(role: role)
        }
    }

    // MARK: - Private Helpers

    private static func mapAllowedMethods(_ factors: [String]) -> [MFAMethod] {
        let normalized = Set(factors.map { $0.lowercased() })
        return MFAMethod.allCases.filter { normalized.contains($0.backendFactor) }
    }

    private static func mapBackendRole(_ role: Auth_V1_UserRole) -> UserRole? {
        switch role {
        case .admin:
            return .admin
        case .manager:
            return .manager
        case .officer:
            return .loanOfficer
        default:
            return nil
        }
    }

    private static func mapProfileToUser(_ profile: Auth_V1_GetMyProfileResponse, role: UserRole) -> User {
        let name: String
        let branch: String

        switch profile.profile {
        case .adminProfile:
            name = nameFromEmail(profile.email)
            branch = "Head Office"
        case .managerProfile(let manager):
            name = manager.name.isEmpty ? nameFromEmail(profile.email) : manager.name
            branch = manager.branch.name.isEmpty ? "Unassigned" : manager.branch.name
        case .officerProfile(let officer):
            name = officer.name.isEmpty ? nameFromEmail(profile.email) : officer.name
            branch = officer.branch.name.isEmpty ? "Unassigned" : officer.branch.name
        default:
            name = nameFromEmail(profile.email)
            branch = "Unassigned"
        }

        return User(
            id: profile.userID,
            name: name,
            email: profile.email,
            role: role,
            branchID: {
                switch profile.profile {
                case .managerProfile(let manager):
                    return manager.branch.branchID.isEmpty ? nil : manager.branch.branchID
                case .officerProfile(let officer):
                    return officer.branch.branchID.isEmpty ? nil : officer.branch.branchID
                default:
                    return nil
                }
            }(),
            branch: branch,
            phone: profile.phone,
            isActive: profile.isActive,
            joinedAt: parseDate(profile.createdAt),
            employeeCode: nil
        )
    }

    private static func parseDate(_ raw: String) -> Date {
        guard !raw.isEmpty else { return Date() }
        let formatter = ISO8601DateFormatter()
        if let parsed = formatter.date(from: raw) {
            return parsed
        }
        return Date()
    }

    private static func nameFromEmail(_ email: String) -> String {
        let base = email.components(separatedBy: "@").first ?? email
        return base.replacingOccurrences(of: ".", with: " ").capitalized
    }
}
