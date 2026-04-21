import SwiftUI
import Combine

@available(iOS 18.0, *)
@MainActor
public final class KYCViewModel: ObservableObject {

    public enum State {
        case idle
        case loading(String)
        case error(String)
        case success
    }

    @Published public var state: State = .idle
    @Published public var errorMessage: String?

    private let initialFullName: String
    private let initialDateOfBirth: String

    @Published public var aadhaarVerifiedName = ""
    @Published public var aadhaarVerifiedDateOfBirth = ""
    @Published public var aadhaarVerifiedGender = ""

    @Published public var panNameAsPerVerification = ""
    @Published public var panDateOfBirthForVerification = ""
    @Published public var panNumber = ""
    @Published public var aadhaarNumber = ""
    @Published public var aadhaarOTP = ""
    @Published public var aadhaarConsentGranted = false
    @Published public var panConsentGranted = false
    @Published public var aadhaarReferenceID = ""
    @Published public var aadhaarProviderTransactionID = ""
    @Published public var panProviderTransactionID = ""
    @Published public var isAadhaarVerified = false
    @Published public var isPanVerified = false
    @Published public var panNameMatch = false
    @Published public var panDOBMatch = false
    @Published public var aadhaarSeedingStatus = ""
    @Published public var selfieImageData: Data?

    public var fullName: String {
        if !aadhaarVerifiedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return aadhaarVerifiedName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return initialFullName
    }

    public var dateOfBirth: String {
        if !aadhaarVerifiedDateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return aadhaarVerifiedDateOfBirth
        }
        if !panDateOfBirthForVerification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return panDateOfBirthForVerification
        }
        return initialDateOfBirth
    }

    private let kycRepository: KYCRepository

    public init(
        fullName: String = "",
        dateOfBirth: String = "",
        kycRepository: KYCRepository = KYCRepository()
    ) {
        self.initialFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.initialDateOfBirth = dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)
        self.panNameAsPerVerification = self.initialFullName
        self.panDateOfBirthForVerification = self.initialDateOfBirth
        self.kycRepository = kycRepository
    }

    public var hasStartedAadhaarStep: Bool {
        !aadhaarReferenceID.isEmpty
    }

    public var isBackendImplementedFlowComplete: Bool {
        isAadhaarVerified && isPanVerified
    }

    public func sendAadhaarOTP() async -> Bool {
        guard aadhaarConsentGranted else {
            return fail(with: "Please record Aadhaar consent before requesting OTP.")
        }

        let trimmedAadhaar = aadhaarNumber.filter(\.isNumber)
        guard trimmedAadhaar.count == 12 else {
            return fail(with: "Enter a valid 12-digit Aadhaar number.")
        }

        errorMessage = nil
        state = .loading("Recording Aadhaar consent...")
        do {
            try await kycRepository.recordUserConsent(type: .aadhaar)
            state = .loading("Sending Aadhaar OTP...")
            let response = try await kycRepository.initiateAadhaarKyc(aadhaarNumber: trimmedAadhaar)
            aadhaarNumber = trimmedAadhaar
            aadhaarReferenceID = response.referenceID
            aadhaarProviderTransactionID = response.providerTransactionID
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func verifyAadhaarOTP() async -> Bool {
        guard !aadhaarReferenceID.isEmpty else {
            return fail(with: "Request an Aadhaar OTP first.")
        }

        let trimmedOTP = aadhaarOTP.filter(\.isNumber)
        guard trimmedOTP.count == 6 else {
            return fail(with: "Enter the 6-digit OTP sent for Aadhaar verification.")
        }

        errorMessage = nil
        state = .loading("Verifying Aadhaar OTP...")
        do {
            let response = try await kycRepository.verifyAadhaarKycOtp(
                referenceID: aadhaarReferenceID,
                otp: trimmedOTP
            )

            guard response.isValid else {
                return fail(with: response.message)
            }

            aadhaarOTP = trimmedOTP
            aadhaarProviderTransactionID = response.providerTransactionID
            isAadhaarVerified = true
            if !response.verifiedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                aadhaarVerifiedName = response.verifiedName.trimmingCharacters(in: .whitespacesAndNewlines)
                panNameAsPerVerification = aadhaarVerifiedName
            }
            if !response.verifiedDateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                aadhaarVerifiedDateOfBirth = response.verifiedDateOfBirth
                panDateOfBirthForVerification = aadhaarVerifiedDateOfBirth
            }
            aadhaarVerifiedGender = response.verifiedGender
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func verifyPan() async -> Bool {
        guard panConsentGranted else {
            return fail(with: "Please record PAN consent before continuing.")
        }

        guard !panNameAsPerVerification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fail(with: "Enter your full name to verify PAN.")
        }

        guard !panDateOfBirthForVerification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fail(with: "Select your date of birth to verify PAN.")
        }

        guard normalizedPAN.count == 10 else {
            return fail(with: "Enter a valid 10-character PAN number.")
        }

        errorMessage = nil
        state = .loading("Recording PAN consent...")
        do {
            try await kycRepository.recordUserConsent(type: .pan)
            state = .loading("Verifying PAN...")
            let response = try await kycRepository.verifyPanKyc(
                pan: normalizedPAN,
                nameAsPerPan: panNameAsPerVerification.trimmingCharacters(in: .whitespacesAndNewlines),
                dateOfBirth: panDateOfBirthForVerification.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            guard response.isValid else {
                return fail(with: "PAN verification failed. Please review your details and try again.")
            }

            panNumber = normalizedPAN
            panProviderTransactionID = response.providerTransactionID
            panNameMatch = response.nameAsPerPanMatch
            panDOBMatch = response.dateOfBirthMatch
            aadhaarSeedingStatus = response.aadhaarSeedingStatus
            isPanVerified = true
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public func pollKYCStatus() async -> KYCStatus {
        do {
            // Fetch authoritative status from the backend.
            let snapshot = try await kycRepository.getBorrowerKycStatus()

            // Sync local flags so UI reflects real backend state.
            isAadhaarVerified = snapshot.isAadhaarVerified
            isPanVerified     = snapshot.isPanVerified

            if snapshot.isAadhaarVerified && snapshot.isPanVerified {
                return .approved
            }

            return .pending
        } catch {
            return .rejected
        }
    }

    public func submitESignature() async -> Bool {
        errorMessage = nil
        state = .loading("Saving e-signature...")
        do {
            try await kycRepository.submitESignature()
            state = .idle
            return true
        } catch {
            return fail(with: error.localizedDescription)
        }
    }

    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Loading..."
    }

    public var normalizedPAN: String {
        panNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    @discardableResult
    private func fail(with message: String) -> Bool {
        state = .error(message)
        errorMessage = message
        return false
    }
}
