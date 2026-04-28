CREATE TYPE loan_query_status AS ENUM ('PENDING', 'COMPLETED');

CREATE TABLE loan_queries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE RESTRICT,
    loan_product_id UUID NOT NULL REFERENCES loan_products(id) ON DELETE RESTRICT,
    branch_id UUID NOT NULL REFERENCES bank_branches(id) ON DELETE RESTRICT,
    requested_amount NUMERIC(15,2) NOT NULL CHECK (requested_amount > 0),
    tenure_months INT NOT NULL CHECK (tenure_months > 0),
    assigned_officer_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status loan_query_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_loan_queries_branch_status_created_at
    ON loan_queries (branch_id, status, created_at DESC);

CREATE INDEX idx_loan_queries_borrower_created_at
    ON loan_queries (borrower_profile_id, created_at DESC);

CREATE INDEX idx_loan_queries_assigned_officer_created_at
    ON loan_queries (assigned_officer_user_id, created_at DESC);
