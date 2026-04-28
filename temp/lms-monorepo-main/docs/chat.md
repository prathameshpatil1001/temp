# Chat API Guide (Frontend)

This document explains `chat.v1.ChatService` APIs and how to use them for real-time messaging.

## Service

- gRPC service: `chat.v1.ChatService`

## RPC List

| RPC | Type | Description |
|-----|------|-------------|
| `ListChatEligibleUsers` | Unary | Returns users the caller can create a direct room with |
| `CreateOrGetDirectRoom` | Unary | Idempotent — returns existing room or creates one |
| `ListMyChatRooms` | Unary | Paginated list of the caller's rooms |
| `ListRoomMessages` | Unary | Paginated message history for a room |
| `SendMessage` | Unary | Persist and broadcast a message to room subscribers |
| `SubscribeRoomMessages` | Server-streaming | Live message feed for a room (includes heartbeat) |

## Authorization

All chat RPCs require JWT auth and the following roles: `borrower`, `officer`, `manager`, `admin`, `dst`.

## gRPC Metadata

- `authorization: Bearer <ACCESS_TOKEN>`

## Room Eligibility Rules

Not every user can chat with every other user. Room creation is gated by role-based eligibility:

- **Borrower** → can chat with DST/officer assigned to their loan applications
- **Officer** → can chat with assigned borrowers, same-branch officers and managers
- **Manager** → can chat with same-branch officers/managers, borrowers with applications in their branch
- **DST** → can chat with borrowers whose applications the DST created, same-branch officers/managers
- **Admin** → can chat with anyone

`ListChatEligibleUsers` returns only users the caller is allowed to create a room with, filtered by these rules.

## Room Canonical Ordering

Direct rooms use canonical UUID ordering: the smaller UUID is always stored as `user_a` and the larger as `user_b`. This ensures there is only one room per user pair. The `CreateOrGetDirectRoom` RPC handles this automatically — the caller does not need to sort IDs.

## 1) ListChatEligibleUsers

Returns users the caller can start a conversation with, optionally filtered by a text `query`.

```json
{
  "query": "john",
  "limit": 20,
  "offset": 0
}
```

Response:

```json
{
  "items": [
    {
      "user_id": "uuid",
      "name": "John Officer",
      "email": "john@example.com",
      "phone": "+919876543210",
      "role": "officer",
      "branch_id": "branch-uuid"
    }
  ]
}
```

Pagination: default limit 20, max 100.

## 2) CreateOrGetDirectRoom

Creates a 1:1 room or returns the existing one. Idempotent per user pair.

```json
{
  "target_user_id": "other-user-uuid",
  "context_application_id": "optional-app-uuid"
}
```

Response:

```json
{
  "room": {
    "id": "room-uuid",
    "room_type": "CHAT_ROOM_TYPE_DIRECT",
    "user_a_id": "smaller-uuid",
    "user_b_id": "larger-uuid",
    "created_by_user_id": "caller-uuid",
    "context_application_id": "optional-app-uuid",
    "created_at": "2025-01-01T00:00:00Z",
    "updated_at": "2025-01-01T00:00:00Z",
    "latest_message": null
  }
}
```

Errors:
- `INVALID_ARGUMENT`: cannot create room with self, invalid UUID
- `PERMISSION_DENIED`: target user is not eligible for chat with caller
- `NOT_FOUND`: caller or target profile missing

## 3) ListMyChatRooms

Paginated list of rooms the caller participates in, ordered by most recent message.

```json
{
  "limit": 20,
  "offset": 0
}
```

Response includes `latest_message` in each room when available.

## 4) ListRoomMessages

Paginated message history. Caller must be a participant in the room.

```json
{
  "room_id": "room-uuid",
  "limit": 20,
  "offset": 0
}
```

Errors:
- `NOT_FOUND`: room does not exist
- `PERMISSION_DENIED`: caller is not a participant

## 5) SendMessage

Persist a message and broadcast it to other subscribers of the room. Caller must be a participant.

```json
{
  "room_id": "room-uuid",
  "message_type": "CHAT_MESSAGE_TYPE_TEXT",
  "body": "Hello!",
  "metadata_json": "{}"
}
```

- `body` is required and must not be empty.
- `metadata_json` defaults to `{}` if omitted.

Response:

```json
{
  "message": {
    "id": "msg-uuid",
    "room_id": "room-uuid",
    "sender_user_id": "caller-uuid",
    "message_type": "CHAT_MESSAGE_TYPE_TEXT",
    "body": "Hello!",
    "metadata_json": "{}",
    "created_at": "2025-01-01T00:00:00Z"
  }
}
```

## 6) SubscribeRoomMessages (Server Streaming)

Opens a long-lived stream for real-time messages in a room.

```json
{
  "room_id": "room-uuid",
  "after_message_id": "optional-msg-uuid"
}
```

- `after_message_id`: if provided, the server first replays all messages after this ID (backlog), then streams live messages.
- The server sends a heartbeat (`ping`) every 30 seconds.

Stream events use `ChatMessageEvent` which is a `oneof`:

```json
{ "message": { ... } }
```

or heartbeat:

```json
{ "heartbeat": "ping" }
```

Lifecycle:
1. Client calls `SubscribeRoomMessages` with a `room_id`.
2. If `after_message_id` is set, server replays backlog messages first.
3. After backlog, server sends live messages as they arrive.
4. Heartbeats are sent every 30s to keep the connection alive.
5. Stream ends when the client disconnects or an error occurs.

## Enums

### ChatRoomType

| Value | Number |
|-------|--------|
| `CHAT_ROOM_TYPE_UNSPECIFIED` | 0 |
| `CHAT_ROOM_TYPE_DIRECT` | 1 |

### ChatMessageType

| Value | Number |
|-------|--------|
| `CHAT_MESSAGE_TYPE_UNSPECIFIED` | 0 |
| `CHAT_MESSAGE_TYPE_TEXT` | 1 |

## In-Memory Hub Notes

The chat hub is an in-memory pub/sub — it does not persist across server restarts. When a server restarts, clients must re-subscribe. Messages that were sent while a client was disconnected are available via `ListRoomMessages` or by providing `after_message_id` on reconnect.