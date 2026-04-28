import Foundation
import GRPCCore

enum APIError: LocalizedError {
    case unauthenticated(String)
    case permissionDenied(String)
    case invalidArgument(String)
    case failedPrecondition(String)
    case notFound(String)
    case alreadyExists(String)
    case internalError(String)
    case unavailable(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .unauthenticated(let message),
             .permissionDenied(let message),
             .invalidArgument(let message),
             .failedPrecondition(let message),
             .notFound(let message),
             .alreadyExists(let message),
             .internalError(let message),
             .unavailable(let message),
             .unknown(let message):
            return message
        }
    }

    static func from(_ error: Error) -> APIError {
        guard let rpcError = error as? RPCError else {
            return .unknown(error.localizedDescription)
        }

        let message = rpcError.message.isEmpty ? "Request failed" : rpcError.message
        switch rpcError.code {
        case .unauthenticated:
            return .unauthenticated(message)
        case .permissionDenied:
            return .permissionDenied(message)
        case .invalidArgument:
            return .invalidArgument(message)
        case .failedPrecondition:
            return .failedPrecondition(message)
        case .notFound:
            return .notFound(message)
        case .alreadyExists:
            return .alreadyExists(message)
        case .internalError:
            return .internalError(message)
        case .unavailable:
            return .unavailable(message)
        default:
            return .unknown(message)
        }
    }
}
