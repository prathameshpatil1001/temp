// OnboardingGRPCClient.swift
// lms_borrower/Networking
//
// Low-level wrapper around the generated gRPC OnboardingService client.
// Mirrors KYCGRPCClient.swift and AuthGRPCClient.swift patterns.

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

// MARK: - OnboardingError

public enum OnboardingError: Error, LocalizedError {
    case unauthenticated
    case alreadyExists
    case invalidInput(String)
    case networkError(String)
    case underlyingError(RPCError)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:          return "You are not authenticated. Please log in again."
        case .alreadyExists:           return "Your borrower profile already exists."
        case .invalidInput(let msg):   return msg
        case .networkError(let msg):   return "Network error: \(msg)"
        case .underlyingError(let e):  return e.message
        case .unknown:                 return "An unknown onboarding error occurred."
        }
    }

    static func from(_ error: Error) -> OnboardingError {
        if let rpc = error as? RPCError {
            switch rpc.code {
            case .unauthenticated:                return .unauthenticated
            case .alreadyExists:                  return .alreadyExists
            case .invalidArgument:                return .invalidInput(rpc.message)
            case .unavailable, .deadlineExceeded: return .networkError(rpc.message)
            default:                              return .underlyingError(rpc)
            }
        }
        return .networkError(error.localizedDescription)
    }
}

// MARK: - OnboardingGRPCClientProtocol

@available(iOS 18.0, *)
public protocol OnboardingGRPCClientProtocol: Sendable {
    func completeBorrowerOnboarding(
        request: Onboarding_V1_CompleteBorrowerOnboardingRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Onboarding_V1_CompleteBorrowerOnboardingResponse
}

// MARK: - OnboardingGRPCClient

@available(iOS 18.0, *)
public final class OnboardingGRPCClient: OnboardingGRPCClientProtocol {

    private let client: Onboarding_V1_OnboardingService.Client<HTTP2ClientTransport.Posix>

    public init(grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client) {
        self.client = Onboarding_V1_OnboardingService.Client(wrapping: grpcClient)
    }

    public func completeBorrowerOnboarding(
        request: Onboarding_V1_CompleteBorrowerOnboardingRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Onboarding_V1_CompleteBorrowerOnboardingResponse {
        do {
            return try await client.completeBorrowerOnboarding(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch {
            // Treat "already exists" as success — profile is already created,
            // subsequent KYC calls will work fine.
            if let onboardingError = error as? OnboardingError,
               case .alreadyExists = onboardingError {
                var resp = Onboarding_V1_CompleteBorrowerOnboardingResponse()
                resp.success = true
                return resp
            }
            if let rpc = error as? RPCError, rpc.code == .alreadyExists {
                var resp = Onboarding_V1_CompleteBorrowerOnboardingResponse()
                resp.success = true
                return resp
            }
            throw OnboardingError.from(error)
        }
    }
}
