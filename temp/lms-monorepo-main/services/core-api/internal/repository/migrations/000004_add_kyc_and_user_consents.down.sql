BEGIN;

DROP INDEX IF EXISTS idx_user_consents_user_type_created_at;
DROP TABLE IF EXISTS user_consents;
DROP TYPE IF EXISTS consent_type_enum;

DROP INDEX IF EXISTS idx_pan_kyc_history_provider_txn;
DROP INDEX IF EXISTS idx_pan_kyc_history_status_attempted_at;
DROP INDEX IF EXISTS idx_pan_kyc_history_profile_attempted_at;
DROP TABLE IF EXISTS borrower_pan_kyc_current;
DROP TABLE IF EXISTS borrower_pan_kyc_history;

DROP INDEX IF EXISTS idx_aadhaar_kyc_history_provider_txn;
DROP INDEX IF EXISTS idx_aadhaar_kyc_history_status_attempted_at;
DROP INDEX IF EXISTS idx_aadhaar_kyc_history_profile_attempted_at;
DROP TABLE IF EXISTS borrower_aadhaar_kyc_current;
DROP TABLE IF EXISTS borrower_aadhaar_kyc_history;

ALTER TABLE borrower_profiles
  DROP COLUMN IF EXISTS pan_verified_at,
  DROP COLUMN IF EXISTS aadhaar_verified_at,
  DROP COLUMN IF EXISTS is_pan_verified,
  DROP COLUMN IF EXISTS is_aadhaar_verified;

COMMIT;
