ALTER TABLE application_documents
    ADD COLUMN reviewed_by_user_id UUID REFERENCES users(id),
    ADD COLUMN reviewed_at TIMESTAMP WITH TIME ZONE;