BEGIN;

DROP INDEX IF EXISTS idx_media_files_user_uploaded_at;
DROP TABLE IF EXISTS media_files;

COMMIT;
