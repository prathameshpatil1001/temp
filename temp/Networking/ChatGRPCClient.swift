// ChatGRPCClient.swift
// DirectSalesTeamApp/Networking
//
// Low-level wrapper around the generated gRPC Chat client.
// Does NOT know about view models or the UI — it only translates Swift methods
// into underlying gRPC calls using the shared GRPCClient.
//
// gRPC-Swift v2 API:
//   - The generated Client<Transport> takes ClientRequest<T> messages.
//   - Default `onResponse` closure returns `try response.message`.
//   - No GRPCChannel type — use GRPCClient<HTTP2ClientTransport.Posix>.

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

// MARK: - ChatError

/// Strongly typed errors specific to the Chat client.
public enum ChatError: Error, LocalizedError {
    case unauthenticated
    case permissionDenied
    case roomNotFound
    case invalidRoomID
    case invalidUserID
    case networkError(String)
    case underlyingError(RPCError)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:       return "You are not authenticated."
        case .permissionDenied:      return "You don't have permission to perform this action."
        case .roomNotFound:          return "Chat room not found."
        case .invalidRoomID:          return "Invalid room ID."
        case .invalidUserID:         return "Invalid user ID."
        case .networkError(let msg): return "Network error: \(msg)"
        case .underlyingError(let e): return e.message
        case .unknown:               return "An unknown error occurred."
        }
    }

    static func from(_ error: Error) -> ChatError {
        if let rpc = error as? RPCError {
            let message = rpc.message.lowercased()

            if message.contains("unauthenticated") || message.contains("not authenticated") {
                return .unauthenticated
            }
            if message.contains("permission denied") || message.contains("permission") {
                return .permissionDenied
            }
            if message.contains("not found") || message.contains("room") {
                return .roomNotFound
            }
            if message.contains("invalid") && message.contains("room") {
                return .invalidRoomID
            }
            if message.contains("invalid") && message.contains("user") {
                return .invalidUserID
            }

            return .underlyingError(rpc)
        }
        return .unknown
    }
}

// MARK: - ChatGRPCClientProtocol

@available(iOS 18.0, *)
public protocol ChatGRPCClientProtocol: Sendable {
    func listChatEligibleUsers(request: Chat_V1_ListChatEligibleUsersRequest, metadata: Metadata, options: CallOptions) async throws -> Chat_V1_ListChatEligibleUsersResponse
    func createOrGetDirectRoom(request: Chat_V1_CreateOrGetDirectRoomRequest, metadata: Metadata, options: CallOptions) async throws -> Chat_V1_CreateOrGetDirectRoomResponse
    func listMyChatRooms(request: Chat_V1_ListMyChatRoomsRequest, metadata: Metadata, options: CallOptions) async throws -> Chat_V1_ListMyChatRoomsResponse
    func listRoomMessages(request: Chat_V1_ListRoomMessagesRequest, metadata: Metadata, options: CallOptions) async throws -> Chat_V1_ListRoomMessagesResponse
    func sendMessage(request: Chat_V1_SendMessageRequest, metadata: Metadata, options: CallOptions) async throws -> Chat_V1_SendMessageResponse
    func subscribeRoomMessages(request: Chat_V1_SubscribeRoomMessagesRequest, metadata: Metadata, options: CallOptions) async throws -> AsyncThrowingStream<Chat_V1_ChatMessageEvent, Error>
}

extension ChatGRPCClientProtocol {
    // Default implementations to make metadata optional
    public func listChatEligibleUsers(request: Chat_V1_ListChatEligibleUsersRequest, options: CallOptions) async throws -> Chat_V1_ListChatEligibleUsersResponse {
        try await listChatEligibleUsers(request: request, metadata: Metadata(), options: options)
    }
    public func createOrGetDirectRoom(request: Chat_V1_CreateOrGetDirectRoomRequest, options: CallOptions) async throws -> Chat_V1_CreateOrGetDirectRoomResponse {
        try await createOrGetDirectRoom(request: request, metadata: Metadata(), options: options)
    }
    public func listMyChatRooms(request: Chat_V1_ListMyChatRoomsRequest, options: CallOptions) async throws -> Chat_V1_ListMyChatRoomsResponse {
        try await listMyChatRooms(request: request, metadata: Metadata(), options: options)
    }
    public func listRoomMessages(request: Chat_V1_ListRoomMessagesRequest, options: CallOptions) async throws -> Chat_V1_ListRoomMessagesResponse {
        try await listRoomMessages(request: request, metadata: Metadata(), options: options)
    }
    public func sendMessage(request: Chat_V1_SendMessageRequest, options: CallOptions) async throws -> Chat_V1_SendMessageResponse {
        try await sendMessage(request: request, metadata: Metadata(), options: options)
    }
    public func subscribeRoomMessages(request: Chat_V1_SubscribeRoomMessagesRequest, options: CallOptions) async throws -> AsyncThrowingStream<Chat_V1_ChatMessageEvent, Error> {
        try await subscribeRoomMessages(request: request, metadata: Metadata(), options: options)
    }
}

// MARK: - ChatGRPCClient

@available(iOS 18.0, *)
public final class ChatGRPCClient: ChatGRPCClientProtocol {

    // The generated Client<Transport> works with any ClientTransport.
    // We pin the concrete type to avoid existential boxing.
    private let client: Chat_V1_ChatService.Client<HTTP2ClientTransport.Posix>

    public init(grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client) {
        self.client = Chat_V1_ChatService.Client(wrapping: grpcClient)
    }

    // MARK: - Room Management

    public func listChatEligibleUsers(
        request: Chat_V1_ListChatEligibleUsersRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Chat_V1_ListChatEligibleUsersResponse {
        do {
            return try await client.listChatEligibleUsers(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw ChatError.from(error) }
    }

    public func createOrGetDirectRoom(
        request: Chat_V1_CreateOrGetDirectRoomRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Chat_V1_CreateOrGetDirectRoomResponse {
        do {
            return try await client.createOrGetDirectRoom(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw ChatError.from(error) }
    }

    public func listMyChatRooms(
        request: Chat_V1_ListMyChatRoomsRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Chat_V1_ListMyChatRoomsResponse {
        do {
            return try await client.listMyChatRooms(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw ChatError.from(error) }
    }

    // MARK: - Messages

    public func listRoomMessages(
        request: Chat_V1_ListRoomMessagesRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Chat_V1_ListRoomMessagesResponse {
        do {
            return try await client.listRoomMessages(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw ChatError.from(error) }
    }

    public func sendMessage(
        request: Chat_V1_SendMessageRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> Chat_V1_SendMessageResponse {
        do {
            return try await client.sendMessage(
                request: .init(message: request, metadata: metadata),
                options: options
            )
        } catch { throw ChatError.from(error) }
    }

    // MARK: - Streaming

    public func subscribeRoomMessages(
        request: Chat_V1_SubscribeRoomMessagesRequest,
        metadata: Metadata,
        options: CallOptions
    ) async throws -> AsyncThrowingStream<Chat_V1_ChatMessageEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await client.subscribeRoomMessages(
                        request,
                        metadata: metadata,
                        options: options,
                        onResponse: { streamingResponse in
                            for try await message in streamingResponse.messages {
                                continuation.yield(message)
                            }
                        }
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
