-- name: CreateLoanProduct :one
INSERT INTO loan_products (
    name,
    category,
    interest_type,
    base_interest_rate,
    min_amount,
    max_amount,
    is_requiring_collateral,
    is_active
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8
) RETURNING *;

-- name: UpdateLoanProduct :one
UPDATE loan_products
SET name = $2,
    category = $3,
    interest_type = $4,
    base_interest_rate = $5,
    min_amount = $6,
    max_amount = $7,
    is_requiring_collateral = $8,
    is_active = $9,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1
  AND is_deleted = false
RETURNING *;

-- name: SoftDeleteLoanProduct :exec
UPDATE loan_products
SET is_deleted = true,
    is_active = false,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- name: GetLoanProductByID :one
SELECT *
FROM loan_products
WHERE id = $1
LIMIT 1;

-- name: ListLoanProducts :many
SELECT *
FROM loan_products
WHERE ($1::bool OR is_deleted = false)
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: UpsertProductEligibilityRule :one
INSERT INTO product_eligibility_rules (
    loan_product_id,
    min_age,
    min_monthly_income,
    min_bureau_score,
    allowed_employment_types
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
)
ON CONFLICT (loan_product_id)
DO UPDATE SET
    min_age = EXCLUDED.min_age,
    min_monthly_income = EXCLUDED.min_monthly_income,
    min_bureau_score = EXCLUDED.min_bureau_score,
    allowed_employment_types = EXCLUDED.allowed_employment_types,
    updated_at = CURRENT_TIMESTAMP
RETURNING *;

-- name: GetProductEligibilityRuleByProductID :one
SELECT *
FROM product_eligibility_rules
WHERE loan_product_id = $1
LIMIT 1;

-- name: DeleteProductFeesByProductID :exec
DELETE FROM product_fees
WHERE loan_product_id = $1;

-- name: CreateProductFee :one
INSERT INTO product_fees (
    loan_product_id,
    fee_type,
    calc_method,
    value
) VALUES (
    $1,
    $2,
    $3,
    $4
) RETURNING *;

-- name: ListProductFeesByProductID :many
SELECT *
FROM product_fees
WHERE loan_product_id = $1
ORDER BY created_at ASC;

-- name: DeleteProductRequiredDocumentsByProductID :exec
DELETE FROM product_required_documents
WHERE loan_product_id = $1;

-- name: CreateProductRequiredDocument :one
INSERT INTO product_required_documents (
    loan_product_id,
    requirement_type,
    is_mandatory
) VALUES (
    $1,
    $2,
    $3
) RETURNING *;

-- name: ListProductRequiredDocumentsByProductID :many
SELECT *
FROM product_required_documents
WHERE loan_product_id = $1
ORDER BY created_at ASC;

-- name: CreateLoanApplication :one
INSERT INTO loan_applications (
    reference_number,
    primary_borrower_profile_id,
    loan_product_id,
    branch_id,
    requested_amount,
    tenure_months,
    offered_interest_rate,
    status,
    assigned_officer_user_id,
    escalation_reason,
    created_by_user_id,
    created_by_role,
    created_by_channel,
    product_snapshot_json,
    disbursement_account_number,
    disbursement_ifsc_code,
    disbursement_bank_name,
    disbursement_account_holder_name
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
    $18
) RETURNING *;

-- name: GetLoanApplicationByID :one
SELECT *
FROM loan_applications
WHERE id = $1
LIMIT 1;

-- name: GetLoanApplicationViewByID :one
SELECT
    la.*,
    lp.name AS product_name,
    lp.category AS product_category,
    bb.name AS branch_name,
    bb.region AS branch_region,
    bb.city AS branch_city
FROM loan_applications la
JOIN loan_products lp ON lp.id = la.loan_product_id
JOIN bank_branches bb ON bb.id = la.branch_id
WHERE la.id = $1
LIMIT 1;

-- name: ListLoanApplicationsForBorrowerProfile :many
SELECT
    la.*,
    lp.name AS product_name,
    bb.name AS branch_name
FROM loan_applications la
JOIN loan_products lp ON lp.id = la.loan_product_id
JOIN bank_branches bb ON bb.id = la.branch_id
WHERE la.primary_borrower_profile_id = $1
ORDER BY la.created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListLoanApplicationsByBranchID :many
SELECT
    la.*,
    lp.name AS product_name,
    bb.name AS branch_name
FROM loan_applications la
JOIN loan_products lp ON lp.id = la.loan_product_id
JOIN bank_branches bb ON bb.id = la.branch_id
WHERE la.branch_id = $1
ORDER BY la.created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListAllLoanApplications :many
SELECT
    la.*,
    lp.name AS product_name,
    bb.name AS branch_name
FROM loan_applications la
JOIN loan_products lp ON lp.id = la.loan_product_id
JOIN bank_branches bb ON bb.id = la.branch_id
ORDER BY la.created_at DESC
LIMIT $1 OFFSET $2;

-- name: ListLoanApplicationsByAssignedOfficer :many
SELECT
    la.*,
    lp.name AS product_name,
    bb.name AS branch_name
FROM loan_applications la
JOIN loan_products lp ON lp.id = la.loan_product_id
JOIN bank_branches bb ON bb.id = la.branch_id
WHERE la.assigned_officer_user_id = $1
ORDER BY la.created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListLoanApplicationsByCreatedByUserID :many
SELECT
    la.*,
    lp.name AS product_name,
    bb.name AS branch_name
FROM loan_applications la
JOIN loan_products lp ON lp.id = la.loan_product_id
JOIN bank_branches bb ON bb.id = la.branch_id
WHERE la.created_by_user_id = $1
ORDER BY la.created_at DESC
LIMIT $2 OFFSET $3;

-- name: UpdateLoanApplicationStatus :exec
UPDATE loan_applications
SET status = $2,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- name: UpdateLoanApplicationTerms :one
UPDATE loan_applications
SET tenure_months = $2,
    offered_interest_rate = $3,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1
RETURNING *;

-- name: AssignLoanApplicationOfficer :exec
UPDATE loan_applications
SET assigned_officer_user_id = $2,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- name: UpdateLoanApplicationEscalation :exec
UPDATE loan_applications
SET escalation_reason = $2,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- name: CreateApplicationCoapplicant :one
INSERT INTO application_coapplicants (
    application_id,
    borrower_profile_id,
    relationship,
    consent_accepted_at
) VALUES (
    $1,
    $2,
    $3,
    $4
) RETURNING *;

-- name: ListApplicationCoapplicants :many
SELECT *
FROM application_coapplicants
WHERE application_id = $1
ORDER BY created_at ASC;

-- name: IsApplicationBorrowerParticipant :one
SELECT EXISTS (
    SELECT 1
    FROM loan_applications la
    WHERE la.id = $1
      AND la.primary_borrower_profile_id = $2
    UNION ALL
    SELECT 1
    FROM application_coapplicants ac
    WHERE ac.application_id = $1
      AND ac.borrower_profile_id = $2
) AS is_participant;

-- name: UpsertApplicationCollateral :one
INSERT INTO application_collateral (
    application_id,
    asset_type,
    estimated_value,
    verification_status,
    collateral_details
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
)
ON CONFLICT (application_id)
DO UPDATE SET
    asset_type = EXCLUDED.asset_type,
    estimated_value = EXCLUDED.estimated_value,
    verification_status = EXCLUDED.verification_status,
    collateral_details = EXCLUDED.collateral_details,
    updated_at = CURRENT_TIMESTAMP
RETURNING *;

-- name: GetApplicationCollateralByApplicationID :one
SELECT *
FROM application_collateral
WHERE application_id = $1
LIMIT 1;

-- name: UpsertLoanVehicle :one
INSERT INTO loan_vehicles (
    application_id,
    make,
    model,
    variant,
    manufacture_year,
    vehicle_identification_number,
    engine_number,
    insurance_id,
    on_road_price
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8,
    $9
)
ON CONFLICT (application_id)
DO UPDATE SET
    make = EXCLUDED.make,
    model = EXCLUDED.model,
    variant = EXCLUDED.variant,
    manufacture_year = EXCLUDED.manufacture_year,
    vehicle_identification_number = EXCLUDED.vehicle_identification_number,
    engine_number = EXCLUDED.engine_number,
    insurance_id = EXCLUDED.insurance_id,
    on_road_price = EXCLUDED.on_road_price,
    updated_at = CURRENT_TIMESTAMP
RETURNING *;

-- name: GetLoanVehicleByApplicationID :one
SELECT *
FROM loan_vehicles
WHERE application_id = $1
LIMIT 1;

-- name: UpsertLoanRealEstate :one
INSERT INTO loan_real_estate (
    application_id,
    prop_type,
    status,
    address_line_1,
    pincode,
    area_sqft,
    deed_document_number,
    agreement_value
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7,
    $8
)
ON CONFLICT (application_id)
DO UPDATE SET
    prop_type = EXCLUDED.prop_type,
    status = EXCLUDED.status,
    address_line_1 = EXCLUDED.address_line_1,
    pincode = EXCLUDED.pincode,
    area_sqft = EXCLUDED.area_sqft,
    deed_document_number = EXCLUDED.deed_document_number,
    agreement_value = EXCLUDED.agreement_value,
    updated_at = CURRENT_TIMESTAMP
RETURNING *;

-- name: GetLoanRealEstateByApplicationID :one
SELECT *
FROM loan_real_estate
WHERE application_id = $1
LIMIT 1;

-- name: CreateApplicationDocument :one
INSERT INTO application_documents (
    application_id,
    borrower_profile_id,
    required_doc_id,
    media_file_id,
    quality_flags,
    verification_status,
    rejection_reason
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6,
    $7
) RETURNING *;

-- name: GetProductRequiredDocumentByIDAndProduct :one
SELECT *
FROM product_required_documents
WHERE id = $1
  AND loan_product_id = $2
LIMIT 1;

-- name: UpdateApplicationDocumentVerification :one
UPDATE application_documents
SET verification_status = $2,
    rejection_reason = $3,
    reviewed_by_user_id = $4,
    reviewed_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1
RETURNING *;

-- name: GetApplicationDocumentByID :one
SELECT *
FROM application_documents
WHERE id = $1;

-- name: CountApprovedRequiredDocsByApplication :one
SELECT COUNT(DISTINCT rd.id) AS approved_count
FROM product_required_documents rd
JOIN loan_applications la ON la.loan_product_id = rd.loan_product_id
WHERE la.id = $1
  AND rd.is_mandatory = true
  AND EXISTS (
    SELECT 1 FROM application_documents ad
    WHERE ad.application_id = la.id
      AND ad.required_doc_id = rd.id
      AND ad.verification_status = 'PASS'
  );

-- name: CountMandatoryRequiredDocsByApplication :one
SELECT COUNT(*) AS total_count
FROM product_required_documents rd
JOIN loan_applications la ON la.loan_product_id = rd.loan_product_id
WHERE la.id = $1
  AND rd.is_mandatory = true;

-- name: ListApplicationDocumentsByApplicationID :many
SELECT *
FROM application_documents
WHERE application_id = $1
ORDER BY created_at DESC;

-- name: GetActiveMediaFileByIDAndUser :one
SELECT *
FROM media_files
WHERE id = $1
  AND user_id = $2
  AND is_deleted = false
LIMIT 1;

-- name: CreateBureauScore :one
INSERT INTO bureau_scores (
    borrower_profile_id,
    application_id,
    provider,
    score,
    fetched_at,
    expires_at
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6
) RETURNING *;

-- name: ListBureauScoresByApplicationID :many
SELECT *
FROM bureau_scores
WHERE application_id = $1
ORDER BY fetched_at DESC;

-- name: GetLatestActiveBureauScoreByBorrowerProfile :one
SELECT *
FROM bureau_scores
WHERE borrower_profile_id = $1
  AND expires_at > CURRENT_TIMESTAMP
ORDER BY fetched_at DESC
LIMIT 1;

-- name: CreateLoan :one
INSERT INTO loans (
    application_id,
    principal_amount,
    interest_rate,
    emi_amount,
    outstanding_balance,
    status
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5,
    $6
) RETURNING *;

-- name: GetLoanByID :one
SELECT *
FROM loans
WHERE id = $1
LIMIT 1;

-- name: GetLoanByApplicationID :one
SELECT *
FROM loans
WHERE application_id = $1
LIMIT 1;

-- name: GetLoanByIDWithApplication :one
SELECT
    l.*,
    la.primary_borrower_profile_id,
    la.branch_id,
    la.assigned_officer_user_id
FROM loans l
JOIN loan_applications la ON la.id = l.application_id
WHERE l.id = $1
LIMIT 1;

-- name: GetLoanByApplicationIDWithApplication :one
SELECT
    l.*,
    la.primary_borrower_profile_id,
    la.branch_id,
    la.assigned_officer_user_id
FROM loans l
JOIN loan_applications la ON la.id = l.application_id
WHERE l.application_id = $1
LIMIT 1;

-- name: ListLoansForBorrowerProfile :many
SELECT l.*
FROM loans l
JOIN loan_applications la ON la.id = l.application_id
WHERE la.primary_borrower_profile_id = $1
ORDER BY l.created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListLoansForAssignedOfficer :many
SELECT l.*
FROM loans l
JOIN loan_applications la ON la.id = l.application_id
WHERE la.assigned_officer_user_id = $1
ORDER BY l.created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListLoansForBranch :many
SELECT l.*
FROM loans l
JOIN loan_applications la ON la.id = l.application_id
WHERE la.branch_id = $1
ORDER BY l.created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListAllLoans :many
SELECT *
FROM loans
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: UpdateLoanStatusAndOutstanding :exec
UPDATE loans
SET status = $2,
    outstanding_balance = $3,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- name: CreateEmiScheduleItem :one
INSERT INTO emi_schedules (
    loan_id,
    installment_number,
    due_date,
    emi_amount,
    status
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
) RETURNING *;

-- name: ListEmiScheduleByLoanID :many
SELECT *
FROM emi_schedules
WHERE loan_id = $1
ORDER BY installment_number ASC;

-- name: GetEmiScheduleByID :one
SELECT *
FROM emi_schedules
WHERE id = $1
LIMIT 1;

-- name: UpdateEmiScheduleStatus :exec
UPDATE emi_schedules
SET status = $2
WHERE id = $1;

-- name: CreatePayment :one
INSERT INTO payments (
    loan_id,
    emi_schedule_id,
    amount,
    external_transaction_id,
    status
) VALUES (
    $1,
    $2,
    $3,
    $4,
    $5
) RETURNING *;

-- name: ListPaymentsByLoanID :many
SELECT *
FROM payments
WHERE loan_id = $1
ORDER BY created_at DESC;

-- name: GetPaymentByExternalTransactionID :one
SELECT *
FROM payments
WHERE external_transaction_id = $1
LIMIT 1;

-- name: DeleteUpcomingEmiSchedulesByLoanID :exec
DELETE FROM emi_schedules
WHERE loan_id = $1 AND status = 'UPCOMING';

-- name: MarkUpcomingSchedulesAsOverdue :execrows
UPDATE emi_schedules
SET status = 'OVERDUE'
WHERE status = 'UPCOMING' AND due_date < CURRENT_DATE;

-- name: UpdateLoanEmiAndOutstanding :one
UPDATE loans
SET emi_amount = $2,
    outstanding_balance = $3,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1
RETURNING *;

-- name: GetTotalSuccessfulPaymentsByLoanID :one
SELECT COALESCE(SUM(amount), 0.0)::numeric AS total_paid
FROM payments
WHERE loan_id = $1 AND status = 'SUCCESS';

-- name: CountPaidEmiInstallmentsByLoanID :one
SELECT COUNT(*) AS paid_count
FROM emi_schedules
WHERE loan_id = $1 AND status = 'PAID';

-- name: CreatePaymentOrder :one
INSERT INTO payment_orders (
    razorpay_order_id,
    loan_id,
    emi_schedule_id,
    amount,
    status
) VALUES (
    $1, $2, $3, $4, $5
)
RETURNING *;

-- name: GetPaymentOrderByRazorpayOrderID :one
SELECT *
FROM payment_orders
WHERE razorpay_order_id = $1;

-- name: UpdatePaymentOrderStatus :exec
UPDATE payment_orders
SET status = $2,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;

-- name: UpdatePaymentOrderVerification :exec
UPDATE payment_orders
SET razorpay_payment_id = $2,
    razorpay_signature = $3,
    status = $4,
    updated_at = CURRENT_TIMESTAMP
WHERE id = $1;
