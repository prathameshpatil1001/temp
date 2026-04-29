-- name: CreateEmployeeUser :one
INSERT INTO users (
    email,
    phone,
    password_hash,
    role,
    is_email_verified,
    is_phone_verified,
    is_active,
    is_requiring_password_change
) VALUES (
    $1,
    $2,
    $3,
    $4,
    true,
    true,
    true,
    true
) RETURNING *;

-- name: CreateAdminUser :one
INSERT INTO users (
    email,
    phone,
    password_hash,
    role,
    is_email_verified,
    is_phone_verified,
    is_active,
    is_requiring_password_change
) VALUES (
    $1,
    $2,
    $3,
    'admin',
    true,
    true,
    true,
    false
) RETURNING *;

-- name: CreateAdminProfile :one
INSERT INTO admin_profiles (
    user_id
) VALUES (
    $1
) RETURNING *;

-- name: CreateManagerProfile :one
INSERT INTO manager_profiles (
    user_id,
    name,
    branch_id
) VALUES (
    $1,
    $2,
    $3
) RETURNING *;

-- name: ListEmployeeAccounts :many
SELECT
    u.id AS user_id,
    COALESCE(mp.name, op.name, 'Administrator') AS name,
    COALESCE(mp.employee_serial, op.employee_serial, 0)::BIGINT AS employee_serial,
    COALESCE(mp.employee_code, op.employee_code) AS employee_code,
    u.email,
    u.phone,
    u.role,
    u.is_active,
    u.is_requiring_password_change,
    COALESCE(mp.branch_id, op.branch_id) AS branch_id,
    b.name AS branch_name,
    b.region AS branch_region,
    b.city AS branch_city,
    u.created_at
FROM users u
LEFT JOIN manager_profiles mp ON mp.user_id = u.id
LEFT JOIN officer_profiles op ON op.user_id = u.id
LEFT JOIN bank_branches b ON b.id = COALESCE(mp.branch_id, op.branch_id)
WHERE u.role IN ('admin', 'manager', 'officer')
  AND u.is_deleted = false
ORDER BY u.created_at DESC
LIMIT $1 OFFSET $2;

-- name: CreateOfficerProfile :one
INSERT INTO officer_profiles (
    user_id,
    name,
    branch_id
) VALUES (
    $1,
    $2,
    $3
) RETURNING *;

-- name: CreateDstUser :one
INSERT INTO users (
    email,
    phone,
    password_hash,
    role,
    is_email_verified,
    is_phone_verified,
    is_active,
    is_requiring_password_change
) VALUES (
    $1,
    $2,
    $3,
    'dst',
    true,
    true,
    true,
    true
) RETURNING *;

-- name: CreateDstProfile :one
INSERT INTO dst_profiles (
    user_id,
    name,
    branch_id
) VALUES (
    $1,
    $2,
    $3
) RETURNING *;

-- name: GetManagerProfileByUserID :one
SELECT * FROM manager_profiles WHERE user_id = $1 LIMIT 1;

-- name: GetAdminProfileByUserID :one
SELECT * FROM admin_profiles WHERE user_id = $1 LIMIT 1;

-- name: GetOfficerProfileByUserID :one
SELECT * FROM officer_profiles WHERE user_id = $1 LIMIT 1;

-- name: GetDstProfileByUserID :one
SELECT * FROM dst_profiles WHERE user_id = $1 LIMIT 1;

-- name: GetDstAccountByUserID :one
SELECT
    u.id AS user_id,
    d.id AS profile_id,
    d.name,
    u.email,
    u.phone,
    u.is_active,
    u.is_requiring_password_change,
    b.id AS branch_id,
    b.name AS branch_name,
    b.region AS branch_region,
    b.city AS branch_city,
    d.created_at
FROM dst_profiles d
JOIN users u ON u.id = d.user_id
JOIN bank_branches b ON b.id = d.branch_id
WHERE d.user_id = $1
  AND u.role = 'dst'
  AND u.is_deleted = false
LIMIT 1;

-- name: ListDstAccountsByBranchID :many
SELECT
    u.id AS user_id,
    d.id AS profile_id,
    d.name,
    u.email,
    u.phone,
    u.is_active,
    u.is_requiring_password_change,
    b.id AS branch_id,
    b.name AS branch_name,
    b.region AS branch_region,
    b.city AS branch_city,
    d.created_at
FROM dst_profiles d
JOIN users u ON u.id = d.user_id
JOIN bank_branches b ON b.id = d.branch_id
WHERE d.branch_id = $1
  AND u.role = 'dst'
  AND u.is_deleted = false
ORDER BY d.created_at DESC
LIMIT $2 OFFSET $3;

-- name: GetManagerProfileByID :one
SELECT * FROM manager_profiles WHERE id = $1 LIMIT 1;

-- name: CreateBankBranch :one
INSERT INTO bank_branches (
    name,
    region,
    city
) VALUES (
    $1,
    $2,
    $3
) RETURNING *;

-- name: GetBankBranchByID :one
SELECT * FROM bank_branches WHERE id = $1 AND is_deleted = false LIMIT 1;

-- name: UpdateBranchDstCommissionByID :exec
UPDATE bank_branches
SET dst_commission = $2
WHERE id = $1;

-- name: UpdateBankBranch :exec
UPDATE bank_branches
SET name = $2,
    region = $3,
    city = $4
WHERE id = $1;

-- name: UpdateManagerBranch :exec
UPDATE manager_profiles
SET branch_id = $2
WHERE user_id = $1;

-- name: UpdateOfficerBranch :exec
UPDATE officer_profiles
SET branch_id = $2
WHERE user_id = $1;

-- name: UpdateEmployeeEmailAndPhone :exec
UPDATE users
SET email = $2,
    phone = $3
WHERE id = $1
  AND is_deleted = false;

-- name: UpdateEmployeePasswordByAdmin :exec
UPDATE users
SET password_hash = $2,
    is_requiring_password_change = true
WHERE id = $1
  AND is_deleted = false;

-- name: ListBankBranches :many
SELECT * FROM bank_branches
WHERE is_deleted = false
ORDER BY name ASC
LIMIT $1 OFFSET $2;

-- name: ListOfficerUserIDsByBranchID :many
SELECT op.user_id
FROM officer_profiles op
JOIN users u ON u.id = op.user_id
WHERE op.branch_id = $1
  AND u.is_active = true
  AND u.is_deleted = false;

-- name: ListOfficersByBranchID :many
SELECT
    u.id AS user_id,
    op.name,
    op.employee_serial::BIGINT AS employee_serial,
    op.employee_code,
    u.email,
    u.phone,
    u.role,
    u.is_active,
    u.is_requiring_password_change,
    op.branch_id,
    b.name AS branch_name,
    b.region AS branch_region,
    b.city AS branch_city,
    u.created_at
FROM officer_profiles op
JOIN users u ON u.id = op.user_id
JOIN bank_branches b ON b.id = op.branch_id
WHERE op.branch_id = $1
  AND u.role = 'officer'
  AND u.is_deleted = false
ORDER BY u.created_at DESC
LIMIT $2 OFFSET $3;

-- name: SoftDeleteBankBranch :exec
UPDATE bank_branches
SET is_deleted = true
WHERE id = $1;

-- name: SoftDeleteUserByID :exec
UPDATE users
SET is_deleted  = true,
    is_active   = false
WHERE id = $1;

-- name: UpdateDstProfileName :exec
UPDATE dst_profiles
SET name = $2
WHERE user_id = $1;
