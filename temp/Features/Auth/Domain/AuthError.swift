// Features/Auth/Domain/AuthError.swift
// LoanOS Borrower App
// Domain-level authentication error definitions used across auth flows.

import Foundation
import GRPCCore

/// Strongly typed errors specific to the Auth client.
public enum AuthError: Error, LocalizedError {
    case unauthenticated
    case invalidCredentials
    case sessionExpired
    case deviceMismatch
    case invalidServerResponse(String)
    case networkError(String)
    case underlyingError(RPCError)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:       return "You are not authenticated."
        case .invalidCredentials:    return "Incorrect email/phone or password. Please try again."
        case .sessionExpired:        return "Your session has expired. Please log in again."
        case .deviceMismatch:        return "Device identity changed. Please log in again using primary credentials."
        case .invalidServerResponse(let msg): return msg
        case .networkError(let msg): return "Network error: \(msg)"
        case .underlyingError(let e): return e.message
        case .unknown:               return "An unknown error occurred."
        }
    }

    static func from(_ error: Error) -> AuthError {
        if let rpc = error as? RPCError {
            let message = rpc.message.lowercased()

            // Device mismatch takes priority.
            if message.contains("device") || message.contains("mismatch") {
                return .deviceMismatch
            }

            // Some backends use unauthenticated for both expired sessions and bad credentials.
            // Distinguish using message hints to avoid showing session-expired on login failures.
            if rpc.code == .unauthenticated {
                let isCredentialFailure = message.contains("invalid")
                    || message.contains("password")
                    || message.contains("credentials")
                    || message.contains("not found")
                    || message.contains("unauthorized")
                    || message.contains("incorrect")
                    || message.contains("wrong")
                return isCredentialFailure ? .invalidCredentials : .sessionExpired
            }

            switch rpc.code {
            case .permissionDenied:
                return .invalidCredentials
            case .unavailable, .deadlineExceeded:
                return .networkError(rpc.message)
            default:
                return .underlyingError(rpc)
            }
        }
        return .networkError(error.localizedDescription)
    }
}

