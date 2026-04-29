DROP INDEX IF EXISTS idx_loan_queries_assigned_officer_created_at;
DROP INDEX IF EXISTS idx_loan_queries_borrower_created_at;
DROP INDEX IF EXISTS idx_loan_queries_branch_status_created_at;

DROP TABLE IF EXISTS loan_queries;

DROP TYPE IF EXISTS loan_query_status;
