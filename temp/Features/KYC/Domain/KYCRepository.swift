// KYCRepository.swift
// lms_borrower/Auth
//
// High-level abstraction for KYC and borrower onboarding flows.
//
// IMPORTANT – required backend call order:
//   1. CompleteBorrowerOnboarding (onboarding.v1) — creates the borrower_profiles row.
//      This MUST succeed before any KYC RPC will work. The backend's requireBorrowerContext
//      returns codes.NotFound ("borrower profile not found") if this row is missing.
//
//   2. RecordUserConsent (Aadhaar)
//   3. InitiateAadhaarKyc  → returns reference_id
//   4. VerifyAadhaarKycOtp
//   5. RecordUserConsent (PAN)
//   6. VerifyPanKyc
//   7. GetBorrowerKycStatus / ListBorrowerKycHistory (optional)
//
// The iOS UX collects all profile fields in two screens before the KYC doc screens.
// The repository accumulates those fields across submitPersonalDetails / submitAddressDetails,
// then fires CompleteBorrowerOnboarding in submitIncomeDetails (the last profile step).

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(iOS 18.0, *)
@MainActor
public final class KYCRepository: Sendable {

    // MARK: - Local result types

    public enum ConsentType {
        case aadhaar
        case pan
    }

    public struct AadhaarInitiationResult {
        public let referenceID: String
        public let providerTransactionID: String
        public let message: String
    }

    public struct AadhaarVerificationResult {
        /// `true` when backend returned `success = true` and status == "VALID".
        public let isValid: Bool
        public let status: String
        public let message: String
        public let providerTransactionID: String
    }

    public struct PanVerificationResult {
        /// `true` when backend returned `success = true`.
        public let isValid: Bool
        public let status: String
        public let providerTransactionID: String
    }

    public struct BorrowerKycStatusSnapshot {
        public let isAadhaarVerified: Bool
        public let isPanVerified: Bool
        public let aadhaarVerifiedAt: String
        public let panVerifiedAt: String
    }

    // MARK: - Pending profile state
    // Accumulated across the two onboarding screens; flushed to the backend
    // in submitIncomeDetails() via CompleteBorrowerOnboarding.

    private var pendingFirstName: String = ""
    private var pendingLastName: String = ""
    private var pendingDateOfBirth: String = ""   // "YYYY-MM-DD"
    private var pendingGender: Onboarding_V1_BorrowerGender = .unspecified
    private var pendingAddressLine1: String = ""
    private var pendingCity: String = ""
    private var pendingState: String = ""
    private var pendingPincode: String = ""

    // MARK: - Dependencies

    private let kycClient: KYCGRPCClientProtocol
    private let onboardingClient: OnboardingGRPCClientProtocol
    private let tokenStore: TokenStore

    // MARK: - Init

    public nonisolated init(
        kycClient: KYCGRPCClientProtocol = KYCGRPCClient(),
        onboardingClient: OnboardingGRPCClientProtocol = OnboardingGRPCClient(),
        tokenStore: TokenStore = .shared
    ) {
        self.kycClient = kycClient
        self.onboardingClient = onboardingClient
        self.tokenStore = tokenStore
    }

    // MARK: - Private helpers

    private func authMetadata() throws -> (options: CallOptions, metadata: Metadata) {
        guard let token = try tokenStore.accessToken() else {
            throw KYCError.unauthenticated
        }
        return AuthCallOptionsFactory.authenticated(accessToken: token)
    }

    // MARK: - Onboarding profile steps

    /// Step 1: Collect personal details + address locally (no network call yet).
    public func submitBorrowerProfileBasics(
        firstName: String,
        lastName: String,
        dateOfBirth: String,    // "YYYY-MM-DD"
        gender: Onboarding_V1_BorrowerGender
    ) {
        pendingFirstName  = firstName
        pendingLastName   = lastName
        pendingDateOfBirth = dateOfBirth
        pendingGender     = gender
    }

    /// Step 1b: Store address locally (called from the same screen; no network call).
    public func submitAddressDetails(
        addressLine1: String,
        city: String,
        state: String,
        postalCode: String
    ) {
        pendingAddressLine1 = addressLine1
        pendingCity         = city
        pendingState        = state
        pendingPincode      = postalCode
    }

    /// Step 2: Flush all collected profile data to the backend as a single
    /// CompleteBorrowerOnboarding call, which creates the borrower_profiles row.
    /// KYC RPCs will 404 until this succeeds.
    public func submitIncomeDetails(
        employmentType: String,
        monthlyIncome: String
    ) async throws {
        let (options, metadata) = try authMetadata()

        let protoEmployment = mapEmploymentType(employmentType)

        var req = Onboarding_V1_CompleteBorrowerOnboardingRequest()
        req.firstName                 = pendingFirstName
        req.lastName                  = pendingLastName
        req.dateOfBirth               = pendingDateOfBirth
        req.gender                    = pendingGender
        req.addressLine1              = pendingAddressLine1
        req.city                      = pendingCity
        req.state                     = pendingState
        req.pincode                   = pendingPincode
        req.employmentType            = protoEmployment
        req.monthlyIncome             = monthlyIncome
        req.profileCompletenessPercent = 80

        let resp = try await onboardingClient.completeBorrowerOnboarding(
            request: req, metadata: metadata, options: options
        )

        guard resp.success else {
            throw KYCError.verificationFailed("Failed to save your profile. Please try again.")
        }
    }

    // MARK: - RecordUserConsent

    public func recordUserConsent(type: ConsentType) async throws {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_RecordUserConsentRequest()
        switch type {
        case .aadhaar:
            req.consentType  = .aadhaarKyc
            req.consentText  = "I authorize identity verification for Aadhaar KYC."
        case .pan:
            req.consentType  = .panKyc
            req.consentText  = "I authorize identity verification for PAN KYC."
        }
        req.consentVersion = "v1"
        req.isGranted      = true
        req.source         = "mobile-ios"
        req.metadataJson   = "{\"screen\":\"kyc-consent\"}"

        let response = try await kycClient.recordUserConsent(request: req, metadata: metadata, options: options)
        guard response.success else {
            throw KYCError.verificationFailed("Failed to record consent. Please try again.")
        }
    }

    // MARK: - InitiateAadhaarKyc

    public func initiateAadhaarKyc(aadhaarNumber: String) async throws -> AadhaarInitiationResult {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_InitiateAadhaarKycRequest()
        req.aadhaarNumber = aadhaarNumber
        req.reason        = "KYC verification"

        let resp = try await kycClient.initiateAadhaarKyc(request: req, metadata: metadata, options: options)

        guard resp.success else {
            throw KYCError.verificationFailed(resp.message.isEmpty ? "Failed to initiate Aadhaar OTP." : resp.message)
        }

        return AadhaarInitiationResult(
            referenceID: resp.referenceID,
            providerTransactionID: resp.providerTransactionID,
            message: resp.message
        )
    }

    // MARK: - VerifyAadhaarKycOtp

    public func verifyAadhaarKycOtp(referenceID: String, otp: String) async throws -> AadhaarVerificationResult {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_VerifyAadhaarKycOtpRequest()
        req.referenceID = referenceID
        req.otp         = otp

        let resp = try await kycClient.verifyAadhaarKycOtp(request: req, metadata: metadata, options: options)

        return AadhaarVerificationResult(
            isValid: resp.success && resp.status.uppercased() == "VALID",
            status: resp.status,
            message: resp.message,
            providerTransactionID: resp.providerTransactionID
        )
    }

    // MARK: - VerifyPanKyc

    public func verifyPanKyc(
        pan: String,
        nameAsPerPan: String,
        dateOfBirth: String
    ) async throws -> PanVerificationResult {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_VerifyPanKycRequest()
        req.pan          = pan
        req.nameAsPerPan = nameAsPerPan
        req.dateOfBirth  = dateOfBirth
        req.reason       = "KYC verification"

        let resp = try await kycClient.verifyPanKyc(request: req, metadata: metadata, options: options)

        return PanVerificationResult(
            isValid: resp.success,
            status: resp.status,
            providerTransactionID: resp.providerTransactionID
        )
    }

    // MARK: - GetBorrowerKycStatus

    public func getBorrowerKycStatus() async throws -> BorrowerKycStatusSnapshot {
        let (options, metadata) = try authMetadata()

        let req  = Kyc_V1_GetBorrowerKycStatusRequest()
        let resp = try await kycClient.getBorrowerKycStatus(request: req, metadata: metadata, options: options)

        return BorrowerKycStatusSnapshot(
            isAadhaarVerified: resp.isAadhaarVerified,
            isPanVerified: resp.isPanVerified,
            aadhaarVerifiedAt: resp.aadhaarVerifiedAt,
            panVerifiedAt: resp.panVerifiedAt
        )
    }

    // MARK: - ListBorrowerKycHistory

    public func listBorrowerKycHistory(
        docType: Kyc_V1_KycDocType = .unspecified,
        limit: Int32 = 20,
        offset: Int32 = 0
    ) async throws -> [Kyc_V1_KycHistoryItem] {
        let (options, metadata) = try authMetadata()

        var req     = Kyc_V1_ListBorrowerKycHistoryRequest()
        req.docType = docType
        req.limit   = limit
        req.offset  = offset

        let resp = try await kycClient.listBorrowerKycHistory(request: req, metadata: metadata, options: options)
        return resp.items
    }

    // MARK: - Legacy compat shim (called from KYCViewModel but replaced by real calls above)

    /// No-op: personal details are now stored locally via submitBorrowerProfileBasics.
    public func submitBorrowerProfileBasics(
        fullName: String,
        dob: String,
        panNumber: String
    ) async throws {
        // The view passes first/last name separately; this overload is unused.
        // Real data is stored by the 4-parameter version.
    }

    /// No-op: e-signature is not yet implemented in the backend.
    public func submitESignature() async throws {}

    // MARK: - Private helpers

    private func mapEmploymentType(_ raw: String) -> Onboarding_V1_BorrowerEmploymentType {
        switch raw.lowercased() {
        case "salaried":                         return .salaried
        case "self-employed", "selfemployed":    return .selfEmployed
        case "business owner", "business":       return .business
        default:                                 return .salaried
        }
    }
}
