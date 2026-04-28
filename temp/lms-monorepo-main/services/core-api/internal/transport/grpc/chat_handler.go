package grpc

import (
	"context"

	chatv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/chatv1"
)

type ChatService interface {
	ListChatEligibleUsers(ctx context.Context, req *chatv1.ListChatEligibleUsersRequest) (*chatv1.ListChatEligibleUsersResponse, error)
	CreateOrGetDirectRoom(ctx context.Context, req *chatv1.CreateOrGetDirectRoomRequest) (*chatv1.CreateOrGetDirectRoomResponse, error)
	ListMyChatRooms(ctx context.Context, req *chatv1.ListMyChatRoomsRequest) (*chatv1.ListMyChatRoomsResponse, error)
	ListRoomMessages(ctx context.Context, req *chatv1.ListRoomMessagesRequest) (*chatv1.ListRoomMessagesResponse, error)
	SendMessage(ctx context.Context, req *chatv1.SendMessageRequest) (*chatv1.SendMessageResponse, error)
	SubscribeRoomMessages(req *chatv1.SubscribeRoomMessagesRequest, srv chatv1.ChatService_SubscribeRoomMessagesServer) error
}

type ChatHandler struct {
	chatv1.UnimplementedChatServiceServer
	chatService ChatService
}

func NewChatHandler(chatService ChatService) *ChatHandler {
	return &ChatHandler{chatService: chatService}
}

func (h *ChatHandler) ListChatEligibleUsers(ctx context.Context, req *chatv1.ListChatEligibleUsersRequest) (*chatv1.ListChatEligibleUsersResponse, error) {
	return h.chatService.ListChatEligibleUsers(ctx, req)
}

func (h *ChatHandler) CreateOrGetDirectRoom(ctx context.Context, req *chatv1.CreateOrGetDirectRoomRequest) (*chatv1.CreateOrGetDirectRoomResponse, error) {
	return h.chatService.CreateOrGetDirectRoom(ctx, req)
}

func (h *ChatHandler) ListMyChatRooms(ctx context.Context, req *chatv1.ListMyChatRoomsRequest) (*chatv1.ListMyChatRoomsResponse, error) {
	return h.chatService.ListMyChatRooms(ctx, req)
}

func (h *ChatHandler) ListRoomMessages(ctx context.Context, req *chatv1.ListRoomMessagesRequest) (*chatv1.ListRoomMessagesResponse, error) {
	return h.chatService.ListRoomMessages(ctx, req)
}

func (h *ChatHandler) SendMessage(ctx context.Context, req *chatv1.SendMessageRequest) (*chatv1.SendMessageResponse, error) {
	return h.chatService.SendMessage(ctx, req)
}

func (h *ChatHandler) SubscribeRoomMessages(req *chatv1.SubscribeRoomMessagesRequest, srv chatv1.ChatService_SubscribeRoomMessagesServer) error {
	return h.chatService.SubscribeRoomMessages(req, srv)
}
