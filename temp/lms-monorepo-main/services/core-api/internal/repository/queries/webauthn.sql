-- name: GetWebAuthnCredentialsByUserID :many
SELECT * FROM webauthn_credentials 
WHERE user_id = $1;

-- name: CreateWebAuthnCredential :one
INSERT INTO webauthn_credentials (
    user_id, credential_id, public_key, sign_count
) VALUES (
    $1, $2, $3, $4
) RETURNING *;

-- name: UpdateWebAuthnCredentialSignCount :exec
UPDATE webauthn_credentials 
SET sign_count = $2 
WHERE credential_id = $1;

-- name: GetWebAuthnCredentialByID :one
SELECT * FROM webauthn_credentials 
WHERE credential_id = $1 
LIMIT 1;
