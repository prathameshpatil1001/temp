// KYCRepository.swift
// lms_borrower/Auth
//
// High-level abstraction for KYC verification flows.
//
// IMPORTANT – required backend call order:
//   1. RecordUserConsent (Aadhaar)
//   2. InitiateAadhaarKyc  → returns reference_id
//   3. VerifyAadhaarKycOtp
//   4. RecordUserConsent (PAN)
//   5. VerifyPanKyc
//   6. GetBorrowerKycStatus / ListBorrowerKycHistory (optional)

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
        public let verifiedName: String
        public let verifiedDateOfBirth: String
        public let verifiedGender: String
    }

    public struct PanVerificationResult {
        /// `true` when backend returned `success = true`.
        public let isValid: Bool
        public let status: String
        public let message: String
        public let providerTransactionID: String
        public let nameAsPerPanMatch: Bool
        public let dateOfBirthMatch: Bool
        public let aadhaarSeedingStatus: String
    }

    public struct BorrowerKycStatusSnapshot {
        public let isAadhaarVerified: Bool
        public let isPanVerified: Bool
        public let aadhaarVerifiedAt: String
        public let panVerifiedAt: String
    }

    // MARK: - Dependencies

    private let kycClient: KYCGRPCClientProtocol
    private let tokenStore: TokenStore

    // MARK: - Init

    public nonisolated init(
        kycClient: KYCGRPCClientProtocol = KYCGRPCClient(),
        tokenStore: TokenStore = .shared
    ) {
        self.kycClient = kycClient
        self.tokenStore = tokenStore
    }

    // MARK: - Private helpers

    private func authMetadata() throws -> (options: CallOptions, metadata: Metadata) {
        guard let token = try tokenStore.accessToken() else {
            throw KYCError.unauthenticated
        }
        return AuthCallOptionsFactory.authenticated(accessToken: token)
    }

    // MARK: - RecordUserConsent

    public func recordUserConsent(type: ConsentType, borrowerUserID: String?) async throws {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_RecordUserConsentRequest()
        if let uid = borrowerUserID {
            req.borrowerUserID = uid
        }
        switch type {
        case .aadhaar:
            req.consentType  = .aadhaarKyc
            req.consentText  = "I consent to Aadhaar-based e-KYC verification under UIDAI guidelines."
        case .pan:
            req.consentType  = .panKyc
            req.consentText  = "I consent to PAN verification."
        }
        req.consentVersion = "v1"
        req.isGranted      = true
        req.source         = "dst_mobile_app"
        req.ipAddress      = currentDeviceIP()
        req.metadataJson   = "{\"screen\":\"kyc-consent\"}"

        let response = try await kycClient.recordUserConsent(request: req, metadata: metadata, options: options)
        guard response.success else {
            throw KYCError.verificationFailed("Failed to record consent. Please try again.")
        }
    }

    // MARK: - InitiateAadhaarKyc

    public func initiateAadhaarKyc(aadhaarNumber: String, borrowerUserID: String?) async throws -> AadhaarInitiationResult {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_InitiateAadhaarKycRequest()
        if let uid = borrowerUserID {
            req.borrowerUserID = uid
        }
        req.aadhaarNumber = aadhaarNumber
        req.reason        = "borrower_kyc"

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

    public func verifyAadhaarKycOtp(referenceID: String, otp: String, borrowerUserID: String?) async throws -> AadhaarVerificationResult {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_VerifyAadhaarKycOtpRequest()
        if let uid = borrowerUserID {
            req.borrowerUserID = uid
        }
        req.referenceID = referenceID
        req.otp         = otp

        let resp = try await kycClient.verifyAadhaarKycOtp(request: req, metadata: metadata, options: options)

        return AadhaarVerificationResult(
            isValid: resp.success && resp.status.uppercased() == "VALID",
            status: resp.status,
            message: resp.message,
            providerTransactionID: resp.providerTransactionID,
            verifiedName: resp.name,
            verifiedDateOfBirth: resp.dateOfBirth,
            verifiedGender: resp.gender
        )
    }

    // MARK: - VerifyPanKyc

    public func verifyPanKyc(
        pan: String,
        nameAsPerPan: String,
        dateOfBirth: String,
        borrowerUserID: String?
    ) async throws -> PanVerificationResult {
        let (options, metadata) = try authMetadata()

        var req = Kyc_V1_VerifyPanKycRequest()
        if let uid = borrowerUserID {
            req.borrowerUserID = uid
        }
        req.pan          = pan
        req.nameAsPerPan = nameAsPerPan
        req.dateOfBirth  = dateOfBirth
        req.reason       = "borrower_kyc"

        let resp = try await kycClient.verifyPanKyc(request: req, metadata: metadata, options: options)

        return PanVerificationResult(
            isValid: resp.success,
            status: resp.status,
            message: resp.message,
            providerTransactionID: resp.providerTransactionID,
            nameAsPerPanMatch: resp.nameAsPerPanMatch,
            dateOfBirthMatch: resp.dateOfBirthMatch,
            aadhaarSeedingStatus: resp.aadhaarSeedingStatus
        )
    }

    // MARK: - GetBorrowerKycStatus

    public func getBorrowerKycStatus(borrowerUserID: String?) async throws -> BorrowerKycStatusSnapshot {
        let (options, metadata) = try authMetadata()

        var req  = Kyc_V1_GetBorrowerKycStatusRequest()
        if let uid = borrowerUserID {
            req.borrowerUserID = uid
        }
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
        offset: Int32 = 0,
        borrowerUserID: String? = nil
    ) async throws -> [Kyc_V1_KycHistoryItem] {
        let (options, metadata) = try authMetadata()

        var req     = Kyc_V1_ListBorrowerKycHistoryRequest()
        if let uid = borrowerUserID {
            req.borrowerUserID = uid
        }
        req.docType = docType
        req.limit   = limit
        req.offset  = offset

        let resp = try await kycClient.listBorrowerKycHistory(request: req, metadata: metadata, options: options)
        return resp.items
    }

    /// No-op: e-signature is not yet implemented in the backend.
    public func submitESignature() async throws {}

    private func currentDeviceIP() -> String {
        "0.0.0.0"
    }
}
