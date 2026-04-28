CREATE TYPE chat_room_type AS ENUM ('DIRECT');
CREATE TYPE chat_message_type AS ENUM ('TEXT');

CREATE TABLE chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_type chat_room_type NOT NULL DEFAULT 'DIRECT',
    user_a_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    context_application_id UUID REFERENCES loan_applications(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_chat_room_user_pair CHECK (user_a_id <> user_b_id)
);

CREATE UNIQUE INDEX uq_chat_rooms_user_pair ON chat_rooms(user_a_id, user_b_id);
CREATE INDEX idx_chat_rooms_user_a ON chat_rooms(user_a_id, updated_at DESC);
CREATE INDEX idx_chat_rooms_user_b ON chat_rooms(user_b_id, updated_at DESC);

CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    message_type chat_message_type NOT NULL DEFAULT 'TEXT',
    body TEXT NOT NULL,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_chat_messages_room_created_at ON chat_messages(room_id, created_at DESC);
