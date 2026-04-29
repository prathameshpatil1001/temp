package chat

import (
	"context"
	"errors"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	chatv1 "github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/generated/chatv1"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type Service interface {
	ListChatEligibleUsers(ctx context.Context, req *chatv1.ListChatEligibleUsersRequest) (*chatv1.ListChatEligibleUsersResponse, error)
	CreateOrGetDirectRoom(ctx context.Context, req *chatv1.CreateOrGetDirectRoomRequest) (*chatv1.CreateOrGetDirectRoomResponse, error)
	ListMyChatRooms(ctx context.Context, req *chatv1.ListMyChatRoomsRequest) (*chatv1.ListMyChatRoomsResponse, error)
	ListRoomMessages(ctx context.Context, req *chatv1.ListRoomMessagesRequest) (*chatv1.ListRoomMessagesResponse, error)
	SendMessage(ctx context.Context, req *chatv1.SendMessageRequest) (*chatv1.SendMessageResponse, error)
	SubscribeRoomMessages(req *chatv1.SubscribeRoomMessagesRequest, srv chatv1.ChatService_SubscribeRoomMessagesServer) error
}

type service struct {
	queries generated.Querier
	hub     *chatHub
}

func NewService(queries generated.Querier) Service {
	return &service{queries: queries, hub: newChatHub()}
}

// --- Chat Hub for streaming ---

type chatHub struct {
	mu        sync.RWMutex
	rooms     map[uuid.UUID]map[uuid.UUID]chan *chatv1.ChatMessageEvent
}

func newChatHub() *chatHub {
	return &chatHub{rooms: make(map[uuid.UUID]map[uuid.UUID]chan *chatv1.ChatMessageEvent)}
}

func (h *chatHub) subscribe(roomID, userID uuid.UUID) chan *chatv1.ChatMessageEvent {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.rooms[roomID] == nil {
		h.rooms[roomID] = make(map[uuid.UUID]chan *chatv1.ChatMessageEvent)
	}
	ch := make(chan *chatv1.ChatMessageEvent, 64)
	h.rooms[roomID][userID] = ch
	return ch
}

func (h *chatHub) unsubscribe(roomID, userID uuid.UUID) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if subs, ok := h.rooms[roomID]; ok {
		if ch, ok2 := subs[userID]; ok2 {
			close(ch)
			delete(subs, userID)
		}
		if len(subs) == 0 {
			delete(h.rooms, roomID)
		}
	}
}

func (h *chatHub) broadcast(roomID uuid.UUID, event *chatv1.ChatMessageEvent, senderID uuid.UUID) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for uid, ch := range h.rooms[roomID] {
		if uid == senderID {
			continue
		}
		select {
		case ch <- event:
		default:
			log.Printf("chat hub drop room=%s user=%s", roomID, uid)
		}
	}
}

// --- Service Methods ---

type chatTargetRow struct {
	UserID     pgtype.UUID
	Email      string
	Phone      string
	Role       string
	TargetName string
	BranchID   pgtype.UUID
}

func (s *service) ListChatEligibleUsers(ctx context.Context, req *chatv1.ListChatEligibleUsersRequest) (*chatv1.ListChatEligibleUsersResponse, error) {
	callerUserID, role, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	limit, offset := normalizePagination(req.GetLimit(), req.GetOffset())
	var rows []chatTargetRow

	switch role {
	case "borrower":
		bRows, bErr := s.queries.ListBorrowerChatTargets(ctx, generated.ListBorrowerChatTargetsParams{
			UserID: uuidToPg(callerUserID),
			Limit:  limit,
			Offset: offset,
		})
		err = bErr
		for _, r := range bRows {
			rows = append(rows, chatTargetRow{UserID: r.UserID, Email: r.Email, Phone: r.Phone, Role: string(r.Role), TargetName: r.TargetName, BranchID: r.BranchID})
		}
	case "officer":
		oRows, oErr := s.queries.ListOfficerChatTargets(ctx, generated.ListOfficerChatTargetsParams{
			AssignedOfficerUserID: uuidToPg(callerUserID),
			Limit:                 limit,
			Offset:                offset,
		})
		err = oErr
		for _, r := range oRows {
			rows = append(rows, chatTargetRow{UserID: r.UserID, Email: r.Email, Phone: r.Phone, Role: string(r.Role), TargetName: r.TargetName, BranchID: r.BranchID})
		}
	case "manager":
		mRows, mErr := s.queries.ListManagerChatTargets(ctx, generated.ListManagerChatTargetsParams{
			UserID: uuidToPg(callerUserID),
			Limit:  limit,
			Offset: offset,
		})
		err = mErr
		for _, r := range mRows {
			rows = append(rows, chatTargetRow{UserID: r.UserID, Email: r.Email, Phone: r.Phone, Role: string(r.Role), TargetName: r.TargetName, BranchID: r.BranchID})
		}
	case "dst":
		dRows, dErr := s.queries.ListDstChatTargets(ctx, generated.ListDstChatTargetsParams{
			CreatedByUserID: uuidToPg(callerUserID),
			Limit:           limit,
			Offset:          offset,
		})
		err = dErr
		for _, r := range dRows {
			rows = append(rows, chatTargetRow{UserID: r.UserID, Email: r.Email, Phone: r.Phone, Role: string(r.Role), TargetName: r.TargetName, BranchID: r.BranchID})
		}
	case "admin":
		aRows, aErr := s.queries.ListAdminChatTargets(ctx, generated.ListAdminChatTargetsParams{
			ID:     uuidToPg(callerUserID),
			Limit:  limit,
			Offset: offset,
		})
		err = aErr
		for _, r := range aRows {
			rows = append(rows, chatTargetRow{UserID: r.UserID, Email: r.Email, Phone: r.Phone, Role: string(r.Role), TargetName: r.TargetName, BranchID: r.BranchID})
		}
	default:
		return nil, status.Error(codes.PermissionDenied, "role cannot list chat targets")
	}

	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list chat targets")
	}

	items := make([]*chatv1.ChatUser, 0, len(rows))
	for _, row := range rows {
		items = append(items, &chatv1.ChatUser{
			UserId:   row.UserID.String(),
			Name:     row.TargetName,
			Email:    row.Email,
			Phone:    row.Phone,
			Role:     row.Role,
			BranchId: nullableUUIDToString(row.BranchID),
		})
	}
	return &chatv1.ListChatEligibleUsersResponse{Items: items}, nil
}

func (s *service) CreateOrGetDirectRoom(ctx context.Context, req *chatv1.CreateOrGetDirectRoomRequest) (*chatv1.CreateOrGetDirectRoomResponse, error) {
	callerUserID, _, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	targetUserID, err := parseUUID(req.GetTargetUserId(), "target_user_id")
	if err != nil {
		return nil, err
	}

	if callerUserID == targetUserID {
		return nil, status.Error(codes.InvalidArgument, "cannot create chat room with self")
	}

	// Canonical ordering for consistent unique index
	userA, userB := canonicalPair(callerUserID, targetUserID)

	// Check if room already exists
	existing, err := s.queries.GetChatRoomByUserPair(ctx, generated.GetChatRoomByUserPairParams{
		UserAID: uuidToPg(userA),
		UserBID: uuidToPg(userB),
	})
	if err == nil {
		return &chatv1.CreateOrGetDirectRoomResponse{Room: s.mapChatRoom(existing, nil)}, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, status.Error(codes.Internal, "failed to check existing room")
	}

	// Room doesn't exist, validate eligibility
	if err := s.validateCanCreateRoom(ctx, callerUserID, targetUserID); err != nil {
		return nil, err
	}

	row, err := s.queries.CreateChatRoom(ctx, generated.CreateChatRoomParams{
		RoomType:        generated.ChatRoomTypeDIRECT,
		UserAID:         uuidToPg(userA),
		UserBID:         uuidToPg(userB),
		CreatedByUserID: uuidToPg(callerUserID),
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create chat room")
	}

	return &chatv1.CreateOrGetDirectRoomResponse{Room: s.mapChatRoom(row, nil)}, nil
}

func (s *service) ListMyChatRooms(ctx context.Context, req *chatv1.ListMyChatRoomsRequest) (*chatv1.ListMyChatRoomsResponse, error) {
	callerUserID, _, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	limit, offset := normalizePagination(req.GetLimit(), req.GetOffset())
	rows, err := s.queries.ListChatRoomsForUser(ctx, generated.ListChatRoomsForUserParams{
		UserAID: uuidToPg(callerUserID),
		Limit:   limit,
		Offset:  offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list chat rooms")
	}

	items := make([]*chatv1.ChatRoom, 0, len(rows))
	for _, row := range rows {
		items = append(items, s.mapChatRoomFromListRow(row))
	}
	return &chatv1.ListMyChatRoomsResponse{Items: items}, nil
}

func (s *service) ListRoomMessages(ctx context.Context, req *chatv1.ListRoomMessagesRequest) (*chatv1.ListRoomMessagesResponse, error) {
	callerUserID, _, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	roomID, err := parseUUID(req.GetRoomId(), "room_id")
	if err != nil {
		return nil, err
	}

	if err := s.ensureRoomParticipant(ctx, roomID, callerUserID); err != nil {
		return nil, err
	}

	limit, offset := normalizePagination(req.GetLimit(), req.GetOffset())
	rows, err := s.queries.ListChatMessagesByRoom(ctx, generated.ListChatMessagesByRoomParams{
		RoomID: uuidToPg(roomID),
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to list messages")
	}

	items := make([]*chatv1.ChatMessage, 0, len(rows))
	for _, row := range rows {
		items = append(items, s.mapChatMessage(row))
	}
	return &chatv1.ListRoomMessagesResponse{Items: items}, nil
}

func (s *service) SendMessage(ctx context.Context, req *chatv1.SendMessageRequest) (*chatv1.SendMessageResponse, error) {
	callerUserID, _, err := requireUserAndRole(ctx)
	if err != nil {
		return nil, err
	}

	roomID, err := parseUUID(req.GetRoomId(), "room_id")
	if err != nil {
		return nil, err
	}

	if err := s.ensureRoomParticipant(ctx, roomID, callerUserID); err != nil {
		return nil, err
	}

	body := strings.TrimSpace(req.GetBody())
	if body == "" {
		return nil, status.Error(codes.InvalidArgument, "body is required")
	}

	msgType := toDBMessageType(req.GetMessageType())
	metadata := []byte("{}")
	if req.GetMetadataJson() != "" {
		metadata = []byte(req.GetMetadataJson())
	}

	row, err := s.queries.CreateChatMessage(ctx, generated.CreateChatMessageParams{
		RoomID:       uuidToPg(roomID),
		SenderUserID: uuidToPg(callerUserID),
		MessageType:  msgType,
		Body:         body,
		MetadataJson: metadata,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to send message")
	}

	msg := s.mapChatMessage(row)

	// Broadcast to other participants
	event := &chatv1.ChatMessageEvent{Payload: &chatv1.ChatMessageEvent_Message{Message: msg}}
	s.hub.broadcast(roomID, event, callerUserID)

	return &chatv1.SendMessageResponse{Message: msg}, nil
}

func (s *service) SubscribeRoomMessages(req *chatv1.SubscribeRoomMessagesRequest, srv chatv1.ChatService_SubscribeRoomMessagesServer) error {
	ctx := srv.Context()
	callerUserID, _, err := requireUserAndRole(ctx)
	if err != nil {
		return err
	}

	roomID, err := parseUUID(req.GetRoomId(), "room_id")
	if err != nil {
		return err
	}

	if err := s.ensureRoomParticipant(ctx, roomID, callerUserID); err != nil {
		return err
	}

	// Send backlog if after_message_id provided
	if req.GetAfterMessageId() != "" {
		afterID, parseErr := parseUUID(req.GetAfterMessageId(), "after_message_id")
		if parseErr != nil {
			return parseErr
		}
		if err := s.sendBacklog(srv, roomID, afterID); err != nil {
			return err
		}
	}

	ch := s.hub.subscribe(roomID, callerUserID)
	defer s.hub.unsubscribe(roomID, callerUserID)

	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case event, ok := <-ch:
			if !ok {
				return nil
			}
			if err := srv.Send(event); err != nil {
				return err
			}
		case <-ticker.C:
			if err := srv.Send(&chatv1.ChatMessageEvent{Payload: &chatv1.ChatMessageEvent_Heartbeat{Heartbeat: "ping"}}); err != nil {
				return err
			}
		case <-ctx.Done():
			return nil
		}
	}
}

func (s *service) sendBacklog(srv chatv1.ChatService_SubscribeRoomMessagesServer, roomID, afterID uuid.UUID) error {
	// Get all messages after the given ID
	rows, err := s.queries.ListChatMessagesByRoom(srv.Context(), generated.ListChatMessagesByRoomParams{
		RoomID: uuidToPg(roomID),
		Limit:  1000,
		Offset: 0,
	})
	if err != nil {
		return status.Error(codes.Internal, "failed to load backlog")
	}

	send := false
	for i := len(rows) - 1; i >= 0; i-- {
		row := rows[i]
		if !send {
			if row.ID == uuidToPg(afterID) {
				send = true
			}
			continue
		}
		event := &chatv1.ChatMessageEvent{Payload: &chatv1.ChatMessageEvent_Message{Message: s.mapChatMessage(row)}}
		if err := srv.Send(event); err != nil {
			return err
		}
	}
	return nil
}

// --- Validation Helpers ---

func (s *service) validateCanCreateRoom(ctx context.Context, callerUserID, targetUserID uuid.UUID) error {
	_, role, err := requireUserAndRole(ctx)
	if err != nil {
		return err
	}

	switch role {
	case "borrower":
		// Can chat with DST or assigned officer of their applications
		return s.validateBorrowerCanChatWith(ctx, callerUserID, targetUserID)
	case "officer":
		// Can chat with assigned borrowers, same branch officers, same branch managers
		return s.validateOfficerCanChatWith(ctx, callerUserID, targetUserID)
	case "manager":
		// Can chat with same branch officers/managers, branch borrowers
		return s.validateManagerCanChatWith(ctx, callerUserID, targetUserID)
	case "dst":
		// Can chat with users of applications they created, same branch officers/managers
		return s.validateDstCanChatWith(ctx, callerUserID, targetUserID)
	case "admin":
		return nil
	default:
		return status.Error(codes.PermissionDenied, "role cannot create chat room")
	}
}

func (s *service) validateBorrowerCanChatWith(ctx context.Context, borrowerUserID, targetUserID uuid.UUID) error {
	profile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(borrowerUserID))
	if err != nil {
		return status.Error(codes.NotFound, "borrower profile not found")
	}

	// Check loan applications
	rows, err := s.queries.ListLoanApplicationsForBorrowerProfile(ctx, generated.ListLoanApplicationsForBorrowerProfileParams{
		PrimaryBorrowerProfileID: profile.ID,
		Limit:                    1000,
		Offset:                   0,
	})
	if err != nil {
		return status.Error(codes.Internal, "failed to validate chat eligibility")
	}
	for _, row := range rows {
		if row.AssignedOfficerUserID.Valid && row.AssignedOfficerUserID.Bytes == targetUserID {
			return nil
		}
		if row.CreatedByUserID.Bytes == targetUserID {
			return nil
		}
	}

	// Check loan queries
	if ok, _ := s.queries.BorrowerHasQueryWithOfficer(ctx, generated.BorrowerHasQueryWithOfficerParams{
		UserID:                uuidToPg(borrowerUserID),
		AssignedOfficerUserID: uuidToPg(targetUserID),
	}); ok {
		return nil
	}
	if ok, _ := s.queries.BorrowerHasQueryInManagerBranch(ctx, generated.BorrowerHasQueryInManagerBranchParams{
		UserID:   uuidToPg(borrowerUserID),
		UserID_2: uuidToPg(targetUserID),
	}); ok {
		return nil
	}

	return status.Error(codes.PermissionDenied, "you can only chat with officers or managers assigned to your loan applications or queries")
}

func (s *service) validateOfficerCanChatWith(ctx context.Context, officerUserID, targetUserID uuid.UUID) error {
	officerProfile, err := s.queries.GetOfficerProfileByUserID(ctx, uuidToPg(officerUserID))
	if err != nil {
		return status.Error(codes.NotFound, "officer profile not found")
	}

	targetUser, err := s.queries.GetUserByID(ctx, uuidToPg(targetUserID))
	if err != nil {
		return status.Error(codes.NotFound, "target user not found")
	}

	switch targetUser.Role {
	case generated.UserRoleBorrower:
		targetBorrowerProfile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "borrower profile not found")
		}
		// Check loan applications
		apps, err := s.queries.ListLoanApplicationsForBorrowerProfile(ctx, generated.ListLoanApplicationsForBorrowerProfileParams{
			PrimaryBorrowerProfileID: targetBorrowerProfile.ID,
			Limit:                    1000,
			Offset:                   0,
		})
		if err != nil {
			return status.Error(codes.Internal, "failed to validate chat eligibility")
		}
		for _, app := range apps {
			if app.AssignedOfficerUserID.Valid && app.AssignedOfficerUserID.Bytes == officerUserID {
				return nil
			}
		}
		// Check loan queries
		if ok, _ := s.queries.OfficerHasQueryForBorrower(ctx, generated.OfficerHasQueryForBorrowerParams{
			AssignedOfficerUserID: uuidToPg(officerUserID),
			UserID:                uuidToPg(targetUserID),
		}); ok {
			return nil
		}
		return status.Error(codes.PermissionDenied, "officer is not assigned to this borrower's loan application or query")
	case generated.UserRoleOfficer:
		targetProfile, err := s.queries.GetOfficerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "target officer not found")
		}
		if targetProfile.BranchID == officerProfile.BranchID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "target officer is not in same branch")
	case generated.UserRoleManager:
		targetProfile, err := s.queries.GetManagerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "target manager not found")
		}
		if targetProfile.BranchID == officerProfile.BranchID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "target manager is not in same branch")
	default:
		return status.Error(codes.PermissionDenied, "officer cannot chat with this role")
	}
}

func (s *service) validateManagerCanChatWith(ctx context.Context, managerUserID, targetUserID uuid.UUID) error {
	managerProfile, err := s.queries.GetManagerProfileByUserID(ctx, uuidToPg(managerUserID))
	if err != nil {
		return status.Error(codes.NotFound, "manager profile not found")
	}

	targetUser, err := s.queries.GetUserByID(ctx, uuidToPg(targetUserID))
	if err != nil {
		return status.Error(codes.NotFound, "target user not found")
	}

	switch targetUser.Role {
	case generated.UserRoleOfficer:
		targetProfile, err := s.queries.GetOfficerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "target officer not found")
		}
		if targetProfile.BranchID == managerProfile.BranchID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "target officer is not in same branch")
	case generated.UserRoleManager:
		targetProfile, err := s.queries.GetManagerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "target manager not found")
		}
		if targetProfile.BranchID == managerProfile.BranchID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "target manager is not in same branch")
	case generated.UserRoleBorrower:
		// Check if borrower has application in manager's branch
		targetBorrowerProfile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "borrower profile not found")
		}
		apps, err := s.queries.ListLoanApplicationsForBorrowerProfile(ctx, generated.ListLoanApplicationsForBorrowerProfileParams{
			PrimaryBorrowerProfileID: targetBorrowerProfile.ID,
			Limit:                    1000,
			Offset:                   0,
		})
		if err != nil {
			return status.Error(codes.Internal, "failed to validate chat eligibility")
		}
		for _, app := range apps {
			if app.BranchID == managerProfile.BranchID {
				return nil
			}
		}
		// Check loan queries
		if ok, _ := s.queries.ManagerBranchHasQueryForBorrower(ctx, generated.ManagerBranchHasQueryForBorrowerParams{
			UserID:   uuidToPg(managerUserID),
			UserID_2: uuidToPg(targetUserID),
		}); ok {
			return nil
		}
		return status.Error(codes.PermissionDenied, "borrower has no loan application or query in your branch")
	default:
		return status.Error(codes.PermissionDenied, "manager cannot chat with this role")
	}
}

func (s *service) validateDstCanChatWith(ctx context.Context, dstUserID, targetUserID uuid.UUID) error {
	dstProfile, err := s.queries.GetDstProfileByUserID(ctx, uuidToPg(dstUserID))
	if err != nil {
		return status.Error(codes.NotFound, "dst profile not found")
	}

	targetUser, err := s.queries.GetUserByID(ctx, uuidToPg(targetUserID))
	if err != nil {
		return status.Error(codes.NotFound, "target user not found")
	}

	switch targetUser.Role {
	case generated.UserRoleBorrower:
		// Check if DST created any application for this borrower
		targetBorrowerProfile, err := s.queries.GetBorrowerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "borrower profile not found")
		}
		apps, err := s.queries.ListLoanApplicationsForBorrowerProfile(ctx, generated.ListLoanApplicationsForBorrowerProfileParams{
			PrimaryBorrowerProfileID: targetBorrowerProfile.ID,
			Limit:                    1000,
			Offset:                   0,
		})
		if err != nil {
			return status.Error(codes.Internal, "failed to validate chat eligibility")
		}
		for _, app := range apps {
			if app.CreatedByUserID.Bytes == dstUserID {
				return nil
			}
		}
		// Check loan queries in DST's branch
		if ok, _ := s.queries.DstHasBorrowerQueryInBranch(ctx, generated.DstHasBorrowerQueryInBranchParams{
			UserID:   uuidToPg(dstUserID),
			UserID_2: uuidToPg(targetUserID),
		}); ok {
			return nil
		}
		return status.Error(codes.PermissionDenied, "dst has not created any application or query for this borrower")
	case generated.UserRoleOfficer:
		targetProfile, err := s.queries.GetOfficerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "target officer not found")
		}
		if targetProfile.BranchID == dstProfile.BranchID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "target officer is not in same branch")
	case generated.UserRoleManager:
		targetProfile, err := s.queries.GetManagerProfileByUserID(ctx, uuidToPg(targetUserID))
		if err != nil {
			return status.Error(codes.NotFound, "target manager not found")
		}
		if targetProfile.BranchID == dstProfile.BranchID {
			return nil
		}
		return status.Error(codes.PermissionDenied, "target manager is not in same branch")
	default:
		return status.Error(codes.PermissionDenied, "dst cannot chat with this role")
	}
}

func (s *service) ensureRoomParticipant(ctx context.Context, roomID, userID uuid.UUID) error {
	room, err := s.queries.GetChatRoomByID(ctx, uuidToPg(roomID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return status.Error(codes.NotFound, "chat room not found")
		}
		return status.Error(codes.Internal, "failed to fetch chat room")
	}
	if room.UserAID != uuidToPg(userID) && room.UserBID != uuidToPg(userID) {
		return status.Error(codes.PermissionDenied, "user is not a participant in this room")
	}
	return nil
}

// --- Mappers ---

func (s *service) mapChatRoom(row generated.ChatRoom, latestMsg *chatv1.ChatMessage) *chatv1.ChatRoom {
	return &chatv1.ChatRoom{
		Id:              row.ID.String(),
		RoomType:        toProtoChatRoomType(row.RoomType),
		UserAId:         row.UserAID.String(),
		UserBId:         row.UserBID.String(),
		CreatedByUserId: row.CreatedByUserID.String(),
		CreatedAt:       timeToString(row.CreatedAt),
		UpdatedAt:       timeToString(row.UpdatedAt),
		LatestMessage:  latestMsg,
	}
}

func (s *service) mapChatRoomFromListRow(row generated.ListChatRoomsForUserRow) *chatv1.ChatRoom {
	var latestMsg *chatv1.ChatMessage
	if row.LatestMessageID.Valid {
		latestMsg = &chatv1.ChatMessage{
			Id:           row.LatestMessageID.String(),
			RoomId:       row.ID.String(),
			SenderUserId: nullableUUIDToString(row.LatestSenderUserID),
			MessageType:  toProtoChatMessageType(row.LatestMessageType),
			Body:         row.LatestMessageBody,
			CreatedAt:    timeToString(row.LatestMessageCreatedAt),
		}
	}
	room := generated.ChatRoom{
		ID:              row.ID,
		RoomType:        row.RoomType,
		UserAID:         row.UserAID,
		UserBID:         row.UserBID,
		CreatedByUserID: row.CreatedByUserID,
		CreatedAt:       row.CreatedAt,
		UpdatedAt:       row.UpdatedAt,
	}
	return s.mapChatRoom(room, latestMsg)
}

func (s *service) mapChatMessage(row generated.ChatMessage) *chatv1.ChatMessage {
	return &chatv1.ChatMessage{
		Id:           row.ID.String(),
		RoomId:       row.RoomID.String(),
		SenderUserId: row.SenderUserID.String(),
		MessageType:  toProtoChatMessageType(row.MessageType),
		Body:         row.Body,
		MetadataJson: string(row.MetadataJson),
		CreatedAt:    timeToString(row.CreatedAt),
	}
}

// --- Helpers ---

func requireUserAndRole(ctx context.Context) (uuid.UUID, string, error) {
	userID, ok := interceptors.UserIDFromContext(ctx)
	if !ok {
		return uuid.UUID{}, "", status.Error(codes.Unauthenticated, "missing user context")
	}
	role, _ := ctx.Value(interceptors.ContextRoleKey).(string)
	if role == "" {
		return uuid.UUID{}, "", status.Error(codes.Unauthenticated, "missing role context")
	}
	return userID, role, nil
}

func parseUUID(v, name string) (uuid.UUID, error) {
	v = strings.TrimSpace(v)
	if v == "" {
		return uuid.UUID{}, status.Errorf(codes.InvalidArgument, "%s is required", name)
	}
	parsed, err := uuid.Parse(v)
	if err != nil {
		return uuid.UUID{}, status.Errorf(codes.InvalidArgument, "invalid %s", name)
	}
	return parsed, nil
}

func uuidToPg(v uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: v, Valid: true}
}

func nullableUUIDToString(v pgtype.UUID) string {
	if !v.Valid {
		return ""
	}
	return uuid.UUID(v.Bytes).String()
}

func timeToString(v pgtype.Timestamptz) string {
	if !v.Valid {
		return ""
	}
	return v.Time.UTC().Format(time.RFC3339)
}

func normalizePagination(limit, offset int32) (int32, int32) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	return limit, offset
}

func canonicalPair(a, b uuid.UUID) (uuid.UUID, uuid.UUID) {
	if strings.Compare(a.String(), b.String()) < 0 {
		return a, b
	}
	return b, a
}

func toProtoChatRoomType(v generated.ChatRoomType) chatv1.ChatRoomType {
	switch v {
	case generated.ChatRoomTypeDIRECT:
		return chatv1.ChatRoomType_CHAT_ROOM_TYPE_DIRECT
	default:
		return chatv1.ChatRoomType_CHAT_ROOM_TYPE_UNSPECIFIED
	}
}

func toProtoChatMessageType(v generated.ChatMessageType) chatv1.ChatMessageType {
	switch v {
	case generated.ChatMessageTypeTEXT:
		return chatv1.ChatMessageType_CHAT_MESSAGE_TYPE_TEXT
	default:
		return chatv1.ChatMessageType_CHAT_MESSAGE_TYPE_UNSPECIFIED
	}
}

func toDBMessageType(v chatv1.ChatMessageType) generated.ChatMessageType {
	switch v {
	case chatv1.ChatMessageType_CHAT_MESSAGE_TYPE_TEXT:
		return generated.ChatMessageTypeTEXT
	default:
		return generated.ChatMessageType("")
	}
}
