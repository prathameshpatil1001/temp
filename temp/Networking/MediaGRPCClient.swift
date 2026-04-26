import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

public enum MediaError: Error, LocalizedError {
    case unauthenticated
    case invalidInput(String)
    case uploadFailed(String)
    case networkError(String)
    case underlyingError(RPCError)

    public var errorDescription: String? {
        switch self {
        case .unauthenticated: return "You are not authenticated. Please log in again."
        case .invalidInput(let msg): return msg
        case .uploadFailed(let msg): return msg
        case .networkError(let msg): return "Network error: \(msg)"
        case .underlyingError(let rpc): return rpc.message
        }
    }

    static func from(_ error: Error) -> MediaError {
        if let rpc = error as? RPCError {
            switch rpc.code {
            case .unauthenticated: return .unauthenticated
            case .invalidArgument: return .invalidInput(rpc.message)
            case .unavailable, .deadlineExceeded: return .networkError(rpc.message)
            default: return .underlyingError(rpc)
            }
        }
        return .networkError(error.localizedDescription)
    }
}

@available(iOS 18.0, *)
public protocol MediaGRPCClientProtocol: Sendable {
    func initiateMediaUpload(request: Media_V1_InitiateMediaUploadRequest, metadata: Metadata, options: CallOptions) async throws -> Media_V1_InitiateMediaUploadResponse
    func completeMediaUpload(request: Media_V1_CompleteMediaUploadRequest, metadata: Metadata, options: CallOptions) async throws -> Media_V1_CompleteMediaUploadResponse
    func listMedia(request: Media_V1_ListMediaRequest, metadata: Metadata, options: CallOptions) async throws -> Media_V1_ListMediaResponse
}

@available(iOS 18.0, *)
public final class MediaGRPCClient: MediaGRPCClientProtocol {
    private let client: Media_V1_MediaService.Client<HTTP2ClientTransport.Posix>

    public init(grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client) {
        self.client = Media_V1_MediaService.Client(wrapping: grpcClient)
    }

    public func initiateMediaUpload(
        request: Media_V1_InitiateMediaUploadRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Media_V1_InitiateMediaUploadResponse {
        do {
            return try await client.initiateMediaUpload(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch {
            throw MediaError.from(error)
        }
    }

    public func completeMediaUpload(
        request: Media_V1_CompleteMediaUploadRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Media_V1_CompleteMediaUploadResponse {
        do {
            return try await client.completeMediaUpload(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch {
            throw MediaError.from(error)
        }
    }

    public func listMedia(
        request: Media_V1_ListMediaRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Media_V1_ListMediaResponse {
        do {
            return try await client.listMedia(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch {
            throw MediaError.from(error)
        }
    }
}
