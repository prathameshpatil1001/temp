-- name: CreateLoanQuery :one
INSERT INTO loan_queries (
    borrower_profile_id,
    loan_product_id,
    branch_id,
    requested_amount,
    tenure_months,
    assigned_officer_user_id,
    status
) VALUES (
    $1, $2, $3, $4, $5, $6, $7
) RETURNING *;

-- name: AssignLoanQueryOfficer :exec
UPDATE loan_queries
SET assigned_officer_user_id = $2,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- name: GetLoanQueryByID :one
SELECT *
FROM loan_queries
WHERE id = $1
LIMIT 1;

-- name: ListLoanQueriesForBorrower :many
SELECT *
FROM loan_queries
WHERE borrower_profile_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListLoanQueriesByBranchID :many
SELECT *
FROM loan_queries
WHERE branch_id = $1
  AND ($2::loan_query_status IS NULL OR status = $2)
ORDER BY created_at DESC
LIMIT $3 OFFSET $4;

-- name: ListLoanQueriesForAssignedOfficer :many
SELECT *
FROM loan_queries
WHERE assigned_officer_user_id = $1
  AND ($2::loan_query_status IS NULL OR status = $2)
ORDER BY created_at DESC
LIMIT $3 OFFSET $4;

-- name: UpdateLoanQueryStatus :exec
UPDATE loan_queries
SET status = $2,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;
