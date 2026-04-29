// KYCGRPCClient.swift
// lms_borrower/Networking
//
// Low-level wrapper around the generated gRPC KYC client.
// Does NOT know about view models or the UI — it only translates Swift methods
// into underlying gRPC calls using the shared GRPCClient.
//
// Mirrors AuthGRPCClient.swift — all KYC RPCs require a bearer token in metadata.

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

// MARK: - KYCError

/// Strongly typed errors specific to the KYC client.
public enum KYCError: Error, LocalizedError {
    case unauthenticated
    case consentRequired
    case verificationFailed(String)
    case invalidInput(String)
    case networkError(String)
    case underlyingError(RPCError)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:              return "You are not authenticated. Please log in again."
        case .consentRequired:             return "Consent is required before proceeding with KYC verification."
        case .verificationFailed(let msg): return msg
        case .invalidInput(let msg):       return msg
        case .networkError(let msg):       return "Network error: \(msg)"
        case .underlyingError(let e):      return e.message
        case .unknown:                     return "An unknown KYC error occurred."
        }
    }

    static func from(_ error: Error) -> KYCError {
        if let rpc = error as? RPCError {
            switch rpc.code {
            case .unauthenticated:                return .unauthenticated
            case .failedPrecondition:             return .consentRequired
            case .invalidArgument:                return .invalidInput(rpc.message)
            case .unavailable, .deadlineExceeded: return .networkError(rpc.message)
            default:                              return .underlyingError(rpc)
            }
        }
        return .networkError(error.localizedDescription)
    }
}

// MARK: - KYCGRPCClientProtocol

@available(iOS 18.0, *)
public protocol KYCGRPCClientProtocol: Sendable {
    func recordUserConsent(request: Kyc_V1_RecordUserConsentRequest, metadata: Metadata, options: CallOptions) async throws -> Kyc_V1_RecordUserConsentResponse
    func initiateAadhaarKyc(request: Kyc_V1_InitiateAadhaarKycRequest, metadata: Metadata, options: CallOptions) async throws -> Kyc_V1_InitiateAadhaarKycResponse
    func verifyAadhaarKycOtp(request: Kyc_V1_VerifyAadhaarKycOtpRequest, metadata: Metadata, options: CallOptions) async throws -> Kyc_V1_VerifyAadhaarKycOtpResponse
    func verifyPanKyc(request: Kyc_V1_VerifyPanKycRequest, metadata: Metadata, options: CallOptions) async throws -> Kyc_V1_VerifyPanKycResponse
    func getBorrowerKycStatus(request: Kyc_V1_GetBorrowerKycStatusRequest, metadata: Metadata, options: CallOptions) async throws -> Kyc_V1_GetBorrowerKycStatusResponse
    func listBorrowerKycHistory(request: Kyc_V1_ListBorrowerKycHistoryRequest, metadata: Metadata, options: CallOptions) async throws -> Kyc_V1_ListBorrowerKycHistoryResponse
}

// MARK: - KYCGRPCClient

@available(iOS 18.0, *)
public final class KYCGRPCClient: KYCGRPCClientProtocol {

    private let client: Kyc_V1_KycService.Client<HTTP2ClientTransport.Posix>

    public init(grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client) {
        self.client = Kyc_V1_KycService.Client(wrapping: grpcClient)
    }

    // MARK: - RecordUserConsent

    public func recordUserConsent(
        request: Kyc_V1_RecordUserConsentRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Kyc_V1_RecordUserConsentResponse {
        do {
            return try await client.recordUserConsent(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw KYCError.from(error) }
    }

    // MARK: - InitiateAadhaarKyc

    public func initiateAadhaarKyc(
        request: Kyc_V1_InitiateAadhaarKycRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Kyc_V1_InitiateAadhaarKycResponse {
        do {
            return try await client.initiateAadhaarKyc(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw KYCError.from(error) }
    }

    // MARK: - VerifyAadhaarKycOtp

    public func verifyAadhaarKycOtp(
        request: Kyc_V1_VerifyAadhaarKycOtpRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Kyc_V1_VerifyAadhaarKycOtpResponse {
        do {
            return try await client.verifyAadhaarKycOtp(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw KYCError.from(error) }
    }

    // MARK: - VerifyPanKyc

    public func verifyPanKyc(
        request: Kyc_V1_VerifyPanKycRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Kyc_V1_VerifyPanKycResponse {
        do {
            return try await client.verifyPanKyc(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw KYCError.from(error) }
    }

    // MARK: - GetBorrowerKycStatus

    public func getBorrowerKycStatus(
        request: Kyc_V1_GetBorrowerKycStatusRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Kyc_V1_GetBorrowerKycStatusResponse {
        do {
            return try await client.getBorrowerKycStatus(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw KYCError.from(error) }
    }

    // MARK: - ListBorrowerKycHistory

    public func listBorrowerKycHistory(
        request: Kyc_V1_ListBorrowerKycHistoryRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Kyc_V1_ListBorrowerKycHistoryResponse {
        do {
            return try await client.listBorrowerKycHistory(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw KYCError.from(error) }
    }
}
