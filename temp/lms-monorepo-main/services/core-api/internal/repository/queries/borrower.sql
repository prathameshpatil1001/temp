-- name: CreateBorrowerProfile :one
INSERT INTO borrower_profiles (
    user_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    address_line1,
    city,
    state,
    pincode,
    employment_type,
    monthly_income,
    profile_completeness_percent,
    cibil_score
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
    $13
) RETURNING *;

-- name: GetBorrowerProfileByUserID :one
SELECT * FROM borrower_profiles WHERE user_id = $1 LIMIT 1;

-- name: GetBorrowerProfileByID :one
SELECT * FROM borrower_profiles WHERE id = $1 LIMIT 1;

-- name: ActivateUser :exec
UPDATE users
SET is_active = true
WHERE id = $1;

-- name: UpdateBorrowerProfile :exec
UPDATE borrower_profiles
SET first_name                 = $2,
    last_name                  = $3,
    date_of_birth              = $4,
    gender                     = $5,
    address_line1              = $6,
    city                       = $7,
    state                      = $8,
    pincode                    = $9,
    employment_type            = $10,
    monthly_income             = $11,
    profile_completeness_percent = $12,
    cibil_score                = $13
WHERE user_id = $1;