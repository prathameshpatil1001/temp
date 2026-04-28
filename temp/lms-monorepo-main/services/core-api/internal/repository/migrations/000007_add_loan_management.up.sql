CREATE TYPE loan_product_category AS ENUM ('PERSONAL', 'HOME', 'VEHICLE', 'EDUCATION');
CREATE TYPE loan_interest_type AS ENUM ('FIXED', 'FLOATING');
CREATE TYPE product_fee_type AS ENUM ('PROCESSING', 'PREPAYMENT', 'LATE_PAYMENT');
CREATE TYPE fee_calc_method AS ENUM ('FLAT', 'PERCENTAGE');
CREATE TYPE document_requirement_type AS ENUM ('IDENTITY', 'ADDRESS', 'INCOME', 'COLLATERAL');
CREATE TYPE loan_application_status AS ENUM (
    'DRAFT',
    'SUBMITTED',
    'UNDER_REVIEW',
    'APPROVED',
    'REJECTED',
    'DISBURSED',
    'CANCELLED',
    'OFFICER_REVIEW',
    'OFFICER_APPROVED',
    'OFFICER_REJECTED',
    'MANAGER_REVIEW',
    'MANAGER_APPROVED',
    'MANAGER_REJECTED'
);
CREATE TYPE coapplicant_relationship AS ENUM ('SPOUSE', 'PARENT', 'SIBLING', 'BUSINESS_PARTNER');
CREATE TYPE collateral_asset_type AS ENUM ('VEHICLE', 'REAL_ESTATE');
CREATE TYPE collateral_verification_status AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');
CREATE TYPE property_type AS ENUM ('APARTMENT', 'VILLA', 'PLOT');
CREATE TYPE property_status AS ENUM ('READY_TO_MOVE', 'UNDER_CONSTRUCTION');
CREATE TYPE document_verification_status AS ENUM ('PENDING', 'PASS', 'FAIL');
CREATE TYPE bureau_provider AS ENUM ('CIBIL', 'EXPERIAN', 'EQUIFAX');
CREATE TYPE loan_status AS ENUM ('ACTIVE', 'CLOSED', 'NPA');
CREATE TYPE emi_status AS ENUM ('UPCOMING', 'PAID', 'OVERDUE');
CREATE TYPE payment_status AS ENUM ('PENDING', 'SUCCESS', 'FAILED');
CREATE TYPE application_created_by_channel AS ENUM ('SELF', 'DST', 'OFFICER');

CREATE TABLE loan_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    category loan_product_category NOT NULL,
    interest_type loan_interest_type NOT NULL,
    base_interest_rate NUMERIC(5,2) NOT NULL CHECK (base_interest_rate >= 0 AND base_interest_rate <= 100),
    min_amount NUMERIC(15,2) NOT NULL CHECK (min_amount >= 0),
    max_amount NUMERIC(15,2) NOT NULL CHECK (max_amount >= min_amount),
    is_requiring_collateral BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_eligibility_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_product_id UUID NOT NULL UNIQUE REFERENCES loan_products(id) ON DELETE CASCADE,
    min_age INT NOT NULL CHECK (min_age >= 18),
    min_monthly_income NUMERIC(15,2) NOT NULL CHECK (min_monthly_income >= 0),
    min_bureau_score INT NOT NULL CHECK (min_bureau_score >= 0 AND min_bureau_score <= 900),
    allowed_employment_types TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_product_id UUID NOT NULL REFERENCES loan_products(id) ON DELETE CASCADE,
    fee_type product_fee_type NOT NULL,
    calc_method fee_calc_method NOT NULL,
    value NUMERIC(15,2) NOT NULL CHECK (value >= 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_required_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_product_id UUID NOT NULL REFERENCES loan_products(id) ON DELETE CASCADE,
    requirement_type document_requirement_type NOT NULL,
    is_mandatory BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE loan_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_number VARCHAR(50) NOT NULL UNIQUE,
    primary_borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE RESTRICT,
    loan_product_id UUID NOT NULL REFERENCES loan_products(id) ON DELETE RESTRICT,
    branch_id UUID NOT NULL REFERENCES bank_branches(id) ON DELETE RESTRICT,
    requested_amount NUMERIC(15,2) NOT NULL CHECK (requested_amount > 0),
    tenure_months INT NOT NULL CHECK (tenure_months > 0),
    offered_interest_rate NUMERIC(5,2) CHECK (offered_interest_rate >= 0 AND offered_interest_rate <= 100),
    status loan_application_status NOT NULL DEFAULT 'DRAFT',
    assigned_officer_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    escalation_reason TEXT,
    created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_by_role user_role NOT NULL,
    created_by_channel application_created_by_channel NOT NULL,
    product_snapshot_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE application_coapplicants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
    borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE RESTRICT,
    relationship coapplicant_relationship NOT NULL,
    consent_accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(application_id, borrower_profile_id)
);

CREATE TABLE application_collateral (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL UNIQUE REFERENCES loan_applications(id) ON DELETE CASCADE,
    asset_type collateral_asset_type NOT NULL,
    estimated_value NUMERIC(15,2) NOT NULL CHECK (estimated_value > 0),
    verification_status collateral_verification_status NOT NULL DEFAULT 'PENDING',
    collateral_details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE loan_vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL UNIQUE REFERENCES loan_applications(id) ON DELETE CASCADE,
    make VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    variant VARCHAR(100) NOT NULL,
    manufacture_year INT NOT NULL CHECK (manufacture_year >= 1900),
    vehicle_identification_number VARCHAR(50) NOT NULL UNIQUE,
    engine_number VARCHAR(50) NOT NULL,
    insurance_id VARCHAR(100) UNIQUE,
    on_road_price NUMERIC(15,2) NOT NULL CHECK (on_road_price > 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE loan_real_estate (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL UNIQUE REFERENCES loan_applications(id) ON DELETE CASCADE,
    prop_type property_type NOT NULL,
    status property_status NOT NULL,
    address_line_1 VARCHAR(255) NOT NULL,
    pincode VARCHAR(20) NOT NULL,
    area_sqft NUMERIC(10,2) NOT NULL CHECK (area_sqft > 0),
    deed_document_number VARCHAR(100) UNIQUE,
    agreement_value NUMERIC(15,2) NOT NULL CHECK (agreement_value > 0),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE application_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
    borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE RESTRICT,
    required_doc_id UUID REFERENCES product_required_documents(id) ON DELETE SET NULL,
    media_file_id UUID NOT NULL REFERENCES media_files(id) ON DELETE RESTRICT,
    quality_flags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    verification_status document_verification_status NOT NULL DEFAULT 'PENDING',
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bureau_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE RESTRICT,
    application_id UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
    provider bureau_provider NOT NULL,
    score INT NOT NULL CHECK (score >= 0 AND score <= 900),
    fetched_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL UNIQUE REFERENCES loan_applications(id) ON DELETE RESTRICT,
    principal_amount NUMERIC(15,2) NOT NULL CHECK (principal_amount > 0),
    interest_rate NUMERIC(5,2) NOT NULL CHECK (interest_rate >= 0 AND interest_rate <= 100),
    emi_amount NUMERIC(15,2) NOT NULL CHECK (emi_amount > 0),
    outstanding_balance NUMERIC(15,2) NOT NULL CHECK (outstanding_balance >= 0),
    status loan_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE emi_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    installment_number INT NOT NULL CHECK (installment_number > 0),
    due_date DATE NOT NULL,
    emi_amount NUMERIC(15,2) NOT NULL CHECK (emi_amount > 0),
    status emi_status NOT NULL DEFAULT 'UPCOMING',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(loan_id, installment_number)
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE RESTRICT,
    emi_schedule_id UUID REFERENCES emi_schedules(id) ON DELETE SET NULL,
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    external_transaction_id VARCHAR(100) NOT NULL UNIQUE,
    status payment_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_loan_products_active_deleted
    ON loan_products (is_active, is_deleted, created_at DESC);

CREATE INDEX idx_loan_applications_primary_borrower_created_at
    ON loan_applications (primary_borrower_profile_id, created_at DESC);

CREATE INDEX idx_loan_applications_branch_status_created_at
    ON loan_applications (branch_id, status, created_at DESC);

CREATE INDEX idx_application_documents_application_borrower
    ON application_documents (application_id, borrower_profile_id, created_at DESC);

CREATE INDEX idx_bureau_scores_application_fetched_at
    ON bureau_scores (application_id, fetched_at DESC);

CREATE INDEX idx_emi_schedules_loan_due_date
    ON emi_schedules (loan_id, due_date ASC);

CREATE INDEX idx_payments_loan_created_at
    ON payments (loan_id, created_at DESC);
