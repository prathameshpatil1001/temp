BEGIN;

CREATE TABLE IF NOT EXISTS media_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  original_file_name TEXT NOT NULL,
  content_type VARCHAR(128) NOT NULL,
  size_bytes BIGINT NOT NULL,
  storage_provider VARCHAR(32) NOT NULL DEFAULT 'r2',
  bucket_name TEXT NOT NULL,
  object_key TEXT NOT NULL UNIQUE,
  etag TEXT,
  file_url TEXT NOT NULL,
  note TEXT,
  uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_deleted BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_media_files_user_uploaded_at
  ON media_files (user_id, uploaded_at DESC);

COMMIT;
