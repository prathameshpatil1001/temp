-- name: CreateMediaFile :one
INSERT INTO media_files (
    user_id,
    original_file_name,
    content_type,
    size_bytes,
    storage_provider,
    bucket_name,
    object_key,
    etag,
    file_url,
    note,
    uploaded_at,
    updated_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9,
    $10,
    $11,
    $12
) RETURNING *;

-- name: ListMediaFilesByUser :many
SELECT *
FROM media_files
WHERE user_id = $1
  AND is_deleted = false
ORDER BY uploaded_at DESC
LIMIT $2
OFFSET $3;
