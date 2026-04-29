-- name: CreateChatRoom :one
INSERT INTO chat_rooms (
    room_type,
    user_a_id,
    user_b_id,
    created_by_user_id
) VALUES (
    $1,
    $2,
    $3,
    $4
) RETURNING *;

-- name: GetChatRoomByUserPair :one
SELECT *
FROM chat_rooms
WHERE (user_a_id = $1 AND user_b_id = $2)
   OR (user_a_id = $2 AND user_b_id = $1)
LIMIT 1;

-- name: GetChatRoomByID :one
SELECT *
FROM chat_rooms
WHERE id = $1
LIMIT 1;

-- name: ListChatRoomsForUser :many
SELECT
    r.*,
    m.id AS latest_message_id,
    m.sender_user_id AS latest_sender_user_id,
    m.message_type AS latest_message_type,
    m.body AS latest_message_body,
    m.created_at AS latest_message_created_at
FROM chat_rooms r
LEFT JOIN LATERAL (
    SELECT *
    FROM chat_messages
    WHERE room_id = r.id
    ORDER BY created_at DESC
    LIMIT 1
) m ON true
WHERE r.user_a_id = $1 OR r.user_b_id = $1
ORDER BY COALESCE(m.created_at, r.created_at) DESC
LIMIT $2 OFFSET $3;

-- name: CreateChatMessage :one
INSERT INTO chat_messages (
    room_id,
    sender_user_id,
    message_type,
    body,
    metadata_json
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
) RETURNING *;

-- name: ListChatMessagesByRoom :many
SELECT *
FROM chat_messages
WHERE room_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: GetChatMessageByID :one
SELECT *
FROM chat_messages
WHERE id = $1
LIMIT 1;

-- Eligibility queries by role.
-- These UNION loan_applications and loan_queries to include both sources.

-- name: ListBorrowerChatTargets :many
SELECT DISTINCT
    u.id AS user_id,
    u.email,
    u.phone,
    u.role,
    COALESCE(op.name, mp.name, dp.name) AS target_name,
    COALESCE(op.branch_id, mp.branch_id, dp.branch_id) AS branch_id
FROM (
    -- Assigned officers and DST creators from loan applications
    SELECT la.assigned_officer_user_id AS user_id FROM loan_applications la
    JOIN borrower_profiles bp ON bp.id = la.primary_borrower_profile_id
    WHERE bp.user_id = $1 AND la.assigned_officer_user_id IS NOT NULL
    UNION
    SELECT la.created_by_user_id AS user_id FROM loan_applications la
    JOIN borrower_profiles bp ON bp.id = la.primary_borrower_profile_id
    WHERE bp.user_id = $1
    -- Assigned officers from loan queries
    UNION
    SELECT lq.assigned_officer_user_id AS user_id FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    WHERE bp.user_id = $1 AND lq.assigned_officer_user_id IS NOT NULL
    -- Branch managers from loan application branches
    UNION
    SELECT mp.user_id FROM loan_applications la
    JOIN borrower_profiles bp ON bp.id = la.primary_borrower_profile_id
    JOIN manager_profiles mp ON mp.branch_id = la.branch_id
    WHERE bp.user_id = $1
    -- Branch managers from loan query branches
    UNION
    SELECT mp.user_id FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    JOIN manager_profiles mp ON mp.branch_id = lq.branch_id
    WHERE bp.user_id = $1
) targets
JOIN users u ON u.id = targets.user_id
LEFT JOIN officer_profiles op ON op.user_id = u.id
LEFT JOIN manager_profiles mp ON mp.user_id = u.id
LEFT JOIN dst_profiles dp ON dp.user_id = u.id
WHERE u.is_deleted = false
  AND u.id <> $1
ORDER BY u.role, target_name
LIMIT $2 OFFSET $3;

-- name: ListOfficerChatTargets :many
WITH officer_branch AS (
    SELECT branch_id FROM officer_profiles WHERE user_id = $1
)
SELECT DISTINCT
    u.id AS user_id,
    u.email,
    u.phone,
    u.role,
    COALESCE(bp.first_name || ' ' || bp.last_name, op.name, mp.name, dp.name) AS target_name,
    COALESCE(op2.branch_id, mp2.branch_id, dp2.branch_id) AS branch_id
FROM (
    -- Borrowers whose loan application this officer is assigned to
    SELECT bp.user_id
    FROM loan_applications la
    JOIN borrower_profiles bp ON bp.id = la.primary_borrower_profile_id
    WHERE la.assigned_officer_user_id = $1
    -- Borrowers whose loan query this officer is assigned to
    UNION
    SELECT bp.user_id
    FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    WHERE lq.assigned_officer_user_id = $1
    -- Same-branch officers
    UNION
    SELECT op2.user_id
    FROM officer_profiles op2, officer_branch ob
    WHERE op2.branch_id = ob.branch_id AND op2.user_id <> $1
    -- Same-branch managers
    UNION
    SELECT mp2.user_id
    FROM manager_profiles mp2, officer_branch ob
    WHERE mp2.branch_id = ob.branch_id
) targets
JOIN users u ON u.id = targets.user_id
LEFT JOIN borrower_profiles bp ON bp.user_id = u.id
LEFT JOIN officer_profiles op ON op.user_id = u.id
LEFT JOIN manager_profiles mp ON mp.user_id = u.id
LEFT JOIN dst_profiles dp ON dp.user_id = u.id
LEFT JOIN officer_profiles op2 ON op2.user_id = $1
LEFT JOIN manager_profiles mp2 ON mp2.user_id = $1
LEFT JOIN dst_profiles dp2 ON dp2.user_id = $1
WHERE u.is_deleted = false
  AND u.id <> $1
ORDER BY u.role, target_name
LIMIT $2 OFFSET $3;

-- name: ListManagerChatTargets :many
WITH manager_branch AS (
    SELECT branch_id FROM manager_profiles WHERE user_id = $1
)
SELECT DISTINCT
    u.id AS user_id,
    u.email,
    u.phone,
    u.role,
    COALESCE(bp.first_name || ' ' || bp.last_name, op.name, mp.name, dp.name) AS target_name,
    COALESCE(mp2.branch_id, op2.branch_id, dp2.branch_id) AS branch_id
FROM (
    -- Same-branch officers
    SELECT op2.user_id
    FROM officer_profiles op2, manager_branch mb
    WHERE op2.branch_id = mb.branch_id
    -- Same-branch managers (excluding self)
    UNION
    SELECT mp2.user_id
    FROM manager_profiles mp2, manager_branch mb
    WHERE mp2.branch_id = mb.branch_id AND mp2.user_id <> $1
    -- Borrowers with loan applications in this branch
    UNION
    SELECT bp.user_id
    FROM loan_applications la
    JOIN borrower_profiles bp ON bp.id = la.primary_borrower_profile_id
    WHERE la.branch_id = (SELECT branch_id FROM manager_profiles WHERE user_id = $1)
    -- Borrowers with loan queries in this branch
    UNION
    SELECT bp.user_id
    FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    WHERE lq.branch_id = (SELECT branch_id FROM manager_profiles WHERE user_id = $1)
) targets
JOIN users u ON u.id = targets.user_id
LEFT JOIN borrower_profiles bp ON bp.user_id = u.id
LEFT JOIN officer_profiles op ON op.user_id = u.id
LEFT JOIN manager_profiles mp ON mp.user_id = u.id
LEFT JOIN dst_profiles dp ON dp.user_id = u.id
LEFT JOIN manager_profiles mp2 ON mp2.user_id = $1
LEFT JOIN officer_profiles op2 ON op2.user_id = $1
LEFT JOIN dst_profiles dp2 ON dp2.user_id = $1
WHERE u.is_deleted = false
  AND u.id <> $1
ORDER BY u.role, target_name
LIMIT $2 OFFSET $3;

-- name: ListDstChatTargets :many
WITH dst_branch AS (
    SELECT branch_id FROM dst_profiles WHERE user_id = $1
)
SELECT DISTINCT
    u.id AS user_id,
    u.email,
    u.phone,
    u.role,
    COALESCE(bp.first_name || ' ' || bp.last_name, op.name, mp.name, dp.name) AS target_name,
    db.branch_id
FROM (
    -- DST created loan applications
    SELECT la.created_by_user_id AS user_id
    FROM loan_applications la
    WHERE la.created_by_user_id = $1
    -- Borrowers in DST's loan applications
    UNION
    SELECT bp.user_id
    FROM loan_applications la
    JOIN borrower_profiles bp ON bp.id = la.primary_borrower_profile_id
    WHERE la.created_by_user_id = $1
    -- Assigned officers for DST's loan applications
    UNION
    SELECT la.assigned_officer_user_id
    FROM loan_applications la
    WHERE la.created_by_user_id = $1
      AND la.assigned_officer_user_id IS NOT NULL
    -- Borrowers in DST's loan queries (borrower who created the query)
    UNION
    SELECT bp.user_id
    FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    WHERE lq.branch_id = (SELECT branch_id FROM dst_profiles WHERE user_id = $1)
      AND lq.assigned_officer_user_id IS NOT NULL
    -- Same-branch officers
    UNION
    SELECT op.user_id
    FROM officer_profiles op, dst_branch db
    WHERE op.branch_id = db.branch_id
    -- Same-branch managers
    UNION
    SELECT mp.user_id
    FROM manager_profiles mp, dst_branch db
    WHERE mp.branch_id = db.branch_id
) targets
JOIN users u ON u.id = targets.user_id
LEFT JOIN borrower_profiles bp ON bp.user_id = u.id
LEFT JOIN officer_profiles op ON op.user_id = u.id
LEFT JOIN manager_profiles mp ON mp.user_id = u.id
LEFT JOIN dst_profiles dp ON dp.user_id = u.id
CROSS JOIN dst_branch db
WHERE u.is_deleted = false
  AND u.id <> $1
ORDER BY u.role, target_name
LIMIT $2 OFFSET $3;

-- name: ListAdminChatTargets :many
SELECT
    u.id AS user_id,
    u.email,
    u.phone,
    u.role,
    COALESCE(bp.first_name || ' ' || bp.last_name, op.name, mp.name, dp.name) AS target_name,
    NULL::UUID AS branch_id
FROM users u
LEFT JOIN borrower_profiles bp ON bp.user_id = u.id
LEFT JOIN officer_profiles op ON op.user_id = u.id
LEFT JOIN manager_profiles mp ON mp.user_id = u.id
LEFT JOIN dst_profiles dp ON dp.user_id = u.id
WHERE u.is_deleted = false
  AND u.id <> $1
ORDER BY u.role, target_name
LIMIT $2 OFFSET $3;

-- Validation queries for CreateOrGetDirectRoom eligibility checks.
-- These check whether a specific target user is eligible for chat with the caller.

-- name: OfficerHasQueryForBorrower :one
SELECT EXISTS (
    SELECT 1 FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    WHERE lq.assigned_officer_user_id = $1
      AND bp.user_id = $2
);

-- name: ManagerBranchHasQueryForBorrower :one
SELECT EXISTS (
    SELECT 1 FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    JOIN manager_profiles mp ON mp.branch_id = lq.branch_id
    WHERE mp.user_id = $1
      AND bp.user_id = $2
);

-- name: BorrowerHasQueryWithOfficer :one
SELECT EXISTS (
    SELECT 1 FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    WHERE bp.user_id = $1
      AND lq.assigned_officer_user_id = $2
);

-- name: BorrowerHasQueryInManagerBranch :one
SELECT EXISTS (
    SELECT 1 FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    JOIN manager_profiles mp ON mp.branch_id = lq.branch_id
    WHERE bp.user_id = $1
      AND mp.user_id = $2
);

-- name: DstHasBorrowerQueryInBranch :one
SELECT EXISTS (
    SELECT 1 FROM loan_queries lq
    JOIN borrower_profiles bp ON bp.id = lq.borrower_profile_id
    JOIN dst_profiles dp ON dp.branch_id = lq.branch_id
    WHERE dp.user_id = $1
      AND bp.user_id = $2
);