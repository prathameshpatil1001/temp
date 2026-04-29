-- name: CreateUserConsent :one
INSERT INTO user_consents (
    user_id,
    consent_type,
    consent_version,
    consent_text,
    consent_text_hash,
    is_granted,
    source,
    ip_address,
    user_agent,
    metadata,
    granted_at,
    revoked_at
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

-- name: GetLatestGrantedConsentByType :one
SELECT *
FROM user_consents
WHERE user_id = $1
  AND consent_type = $2
  AND is_granted = true
ORDER BY created_at DESC
LIMIT 1;

-- name: CreateBorrowerAadhaarKycHistory :one
INSERT INTO borrower_aadhaar_kyc_history (
    user_id,
    borrower_profile_id,
    provider,
    provider_transaction_id,
    provider_reference_id,
    status,
    failure_code,
    failure_reason,
    provider_message,
    name,
    gender,
    date_of_birth,
    year_of_birth,
    care_of,
    full_address,
    country,
    district,
    house,
    landmark,
    pincode,
    post_office,
    state,
    street,
    subdistrict,
    vtc,
    email_hash,
    mobile_hash,
    raw_response,
    attempted_at
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
    $12,
    $13,
    $14,
    $15,
    $16,
    $17,
    $18,
    $19,
    $20,
    $21,
    $22,
    $23,
    $24,
    $25,
    $26,
    $27,
    $28,
    $29
) RETURNING *;

-- name: UpsertBorrowerAadhaarKycCurrent :one
INSERT INTO borrower_aadhaar_kyc_current (
    user_id,
    borrower_profile_id,
    source_history_id,
    provider,
    provider_transaction_id,
    provider_reference_id,
    status,
    provider_message,
    name,
    gender,
    date_of_birth,
    year_of_birth,
    care_of,
    full_address,
    country,
    district,
    house,
    landmark,
    pincode,
    post_office,
    state,
    street,
    subdistrict,
    vtc,
    email_hash,
    mobile_hash,
    raw_response,
    verified_at,
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
    $12,
    $13,
    $14,
    $15,
    $16,
    $17,
    $18,
    $19,
    $20,
    $21,
    $22,
    $23,
    $24,
    $25,
    $26,
    $27,
    $28,
    $29
)
ON CONFLICT (borrower_profile_id)
DO UPDATE SET
    source_history_id = EXCLUDED.source_history_id,
    provider = EXCLUDED.provider,
    provider_transaction_id = EXCLUDED.provider_transaction_id,
    provider_reference_id = EXCLUDED.provider_reference_id,
    status = EXCLUDED.status,
    provider_message = EXCLUDED.provider_message,
    name = EXCLUDED.name,
    gender = EXCLUDED.gender,
    date_of_birth = EXCLUDED.date_of_birth,
    year_of_birth = EXCLUDED.year_of_birth,
    care_of = EXCLUDED.care_of,
    full_address = EXCLUDED.full_address,
    country = EXCLUDED.country,
    district = EXCLUDED.district,
    house = EXCLUDED.house,
    landmark = EXCLUDED.landmark,
    pincode = EXCLUDED.pincode,
    post_office = EXCLUDED.post_office,
    state = EXCLUDED.state,
    street = EXCLUDED.street,
    subdistrict = EXCLUDED.subdistrict,
    vtc = EXCLUDED.vtc,
    email_hash = EXCLUDED.email_hash,
    mobile_hash = EXCLUDED.mobile_hash,
    raw_response = EXCLUDED.raw_response,
    verified_at = EXCLUDED.verified_at,
    updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: CreateBorrowerPanKycHistory :one
INSERT INTO borrower_pan_kyc_history (
    user_id,
    borrower_profile_id,
    provider,
    provider_transaction_id,
    status,
    failure_code,
    failure_reason,
    provider_message,
    pan_masked,
    category,
    remarks,
    name_as_per_pan_match,
    date_of_birth_match,
    aadhaar_seeding_status,
    raw_response,
    attempted_at
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
    $12,
    $13,
    $14,
    $15,
    $16
) RETURNING *;

-- name: UpsertBorrowerPanKycCurrent :one
INSERT INTO borrower_pan_kyc_current (
    user_id,
    borrower_profile_id,
    source_history_id,
    provider,
    provider_transaction_id,
    status,
    provider_message,
    pan_masked,
    category,
    remarks,
    name_as_per_pan_match,
    date_of_birth_match,
    aadhaar_seeding_status,
    raw_response,
    verified_at,
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
    $12,
    $13,
    $14,
    $15,
    $16
)
ON CONFLICT (borrower_profile_id)
DO UPDATE SET
    source_history_id = EXCLUDED.source_history_id,
    provider = EXCLUDED.provider,
    provider_transaction_id = EXCLUDED.provider_transaction_id,
    status = EXCLUDED.status,
    provider_message = EXCLUDED.provider_message,
    pan_masked = EXCLUDED.pan_masked,
    category = EXCLUDED.category,
    remarks = EXCLUDED.remarks,
    name_as_per_pan_match = EXCLUDED.name_as_per_pan_match,
    date_of_birth_match = EXCLUDED.date_of_birth_match,
    aadhaar_seeding_status = EXCLUDED.aadhaar_seeding_status,
    raw_response = EXCLUDED.raw_response,
    verified_at = EXCLUDED.verified_at,
    updated_at = EXCLUDED.updated_at
RETURNING *;

-- name: MarkBorrowerAadhaarVerified :exec
UPDATE borrower_profiles
SET is_aadhaar_verified = true,
    aadhaar_verified_at = COALESCE(aadhaar_verified_at, $2)
WHERE id = $1;

-- name: MarkBorrowerPanVerified :exec
UPDATE borrower_profiles
SET is_pan_verified = true,
    pan_verified_at = COALESCE(pan_verified_at, $2)
WHERE id = $1;

-- name: ListBorrowerAadhaarKycHistory :many
SELECT *
FROM borrower_aadhaar_kyc_history
WHERE borrower_profile_id = $1
ORDER BY attempted_at DESC
LIMIT $2
OFFSET $3;

-- name: ListBorrowerPanKycHistory :many
SELECT *
FROM borrower_pan_kyc_history
WHERE borrower_profile_id = $1
ORDER BY attempted_at DESC
LIMIT $2
OFFSET $3;
