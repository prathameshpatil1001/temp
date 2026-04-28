// ChatService.swift
// DirectSalesTeamApp/Services
//
// High-level service for Chat functionality.
// Handles business logic and provides a clean API for ViewModels.

import Foundation
import GRPCCore
import SwiftProtobuf
import Combine

// MARK: - ChatServiceProtocol

@available(iOS 18.0, *)
public protocol ChatServiceProtocol: Sendable {
    func listEligibleUsers(query: String, limit: Int, offset: Int) async throws -> [ChatUser]
    func createOrGetDirectRoom(targetUserID: String, contextApplicationID: String?) async throws -> ChatRoom
    func listMyChatRooms(limit: Int, offset: Int) async throws -> [ChatRoom]
    func listRoomMessages(roomID: String, limit: Int, offset: Int) async throws -> [ChatDomainMessage]
    func sendMessage(roomID: String, body: String, messageType: ChatMessageType, metadataJSON: String?) async throws -> ChatDomainMessage
    func subscribeToRoomMessages(roomID: String, afterMessageID: String?) -> AsyncThrowingStream<ChatMessageEvent, Error>
}

// MARK: - ChatService

@available(iOS 18.0, *)
public final class ChatService: ChatServiceProtocol {

    private let grpcClient: ChatGRPCClientProtocol

    public init(
        grpcClient: ChatGRPCClientProtocol = ChatGRPCClient()
    ) {
        self.grpcClient = grpcClient
    }

    // MARK: - Auth Helper

    private func requireAccessToken() throws -> String {
        guard let token = try TokenStore.shared.accessToken(), !token.isEmpty else {
            throw ChatError.unauthenticated
        }
        return token
    }

    // MARK: - User Discovery

    public func listEligibleUsers(
        query: String = "",
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatUser] {
        let accessToken = try requireAccessToken()
        let request = Chat_V1_ListChatEligibleUsersRequest.with {
            $0.query = query
            $0.limit = Int32(limit)
            $0.offset = Int32(offset)
        }

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: accessToken)
        let response = try await grpcClient.listChatEligibleUsers(
            request: request,
            metadata: metadata,
            options: options
        )

        return response.items.map { ChatUser(from: $0) }
    }

    // MARK: - Room Management

    public func createOrGetDirectRoom(
        targetUserID: String,
        contextApplicationID: String? = nil
    ) async throws -> ChatRoom {
        let accessToken = try requireAccessToken()
        let request = Chat_V1_CreateOrGetDirectRoomRequest.with {
            $0.targetUserID = targetUserID
            if let appID = contextApplicationID {
                $0.contextApplicationID = appID
            }
        }

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: accessToken)
        let response = try await grpcClient.createOrGetDirectRoom(
            request: request,
            metadata: metadata,
            options: options
        )

        return ChatRoom(from: response.room)
    }

    public func listMyChatRooms(
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [ChatRoom] {
        let accessToken = try requireAccessToken()
        let request = Chat_V1_ListMyChatRoomsRequest.with {
            $0.limit = Int32(limit)
            $0.offset = Int32(offset)
        }

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: accessToken)
        let response = try await grpcClient.listMyChatRooms(
            request: request,
            metadata: metadata,
            options: options
        )

        return response.items.map { ChatRoom(from: $0) }
    }

    // MARK: - Messages

    public func listRoomMessages(
        roomID: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [ChatDomainMessage] {
        let accessToken = try requireAccessToken()
        let request = Chat_V1_ListRoomMessagesRequest.with {
            $0.roomID = roomID
            $0.limit = Int32(limit)
            $0.offset = Int32(offset)
        }

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: accessToken)
        let response = try await grpcClient.listRoomMessages(
            request: request,
            metadata: metadata,
            options: options
        )

        return response.items.map { ChatDomainMessage(from: $0) }
    }

    public func sendMessage(
        roomID: String,
        body: String,
        messageType: ChatMessageType = .text,
        metadataJSON: String? = nil
    ) async throws -> ChatDomainMessage {
        let accessToken = try requireAccessToken()
        let request = Chat_V1_SendMessageRequest.with {
            $0.roomID = roomID
            $0.messageType = messageType.protoValue
            $0.body = body
            if let metadata = metadataJSON {
                $0.metadataJson = metadata
            }
        }

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: accessToken)
        let response = try await grpcClient.sendMessage(
            request: request,
            metadata: metadata,
            options: options
        )

        return ChatDomainMessage(from: response.message)
    }

    // MARK: - Streaming

    public func subscribeToRoomMessages(
        roomID: String,
        afterMessageID: String? = nil
    ) -> AsyncThrowingStream<ChatMessageEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let accessToken: String
                    do {
                        accessToken = try self.requireAccessToken()
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }

                    let request = Chat_V1_SubscribeRoomMessagesRequest.with {
                        $0.roomID = roomID
                        if let msgID = afterMessageID {
                            $0.afterMessageID = msgID
                        }
                    }

                    let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: accessToken)
                    let protoStream = try await grpcClient.subscribeRoomMessages(
                        request: request,
                        metadata: metadata,
                        options: options
                    )

                    for try await protoEvent in protoStream {
                        let event = ChatMessageEvent(from: protoEvent)
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ChatError.from(error))
                }
            }
        }
    }
}