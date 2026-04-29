BEGIN;

ALTER TABLE borrower_profiles
  ADD COLUMN IF NOT EXISTS is_aadhaar_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_pan_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS aadhaar_verified_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS pan_verified_at TIMESTAMP WITH TIME ZONE;

CREATE TYPE consent_type_enum AS ENUM ('aadhar_kyc', 'pan_kyc');

CREATE TABLE IF NOT EXISTS borrower_aadhaar_kyc_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE CASCADE,
  provider VARCHAR(64) NOT NULL,
  provider_transaction_id VARCHAR(128),
  provider_reference_id BIGINT,
  status VARCHAR(32) NOT NULL,
  failure_code VARCHAR(64),
  failure_reason TEXT,
  provider_message TEXT,
  name VARCHAR(255),
  gender VARCHAR(16),
  date_of_birth VARCHAR(16),
  year_of_birth VARCHAR(8),
  care_of TEXT,
  full_address TEXT,
  country VARCHAR(100),
  district VARCHAR(100),
  house TEXT,
  landmark TEXT,
  pincode VARCHAR(20),
  post_office VARCHAR(100),
  state VARCHAR(100),
  street TEXT,
  subdistrict VARCHAR(100),
  vtc VARCHAR(100),
  email_hash TEXT,
  mobile_hash TEXT,
  raw_response JSONB,
  attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS borrower_aadhaar_kyc_current (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  borrower_profile_id UUID NOT NULL UNIQUE REFERENCES borrower_profiles(id) ON DELETE CASCADE,
  source_history_id UUID NOT NULL REFERENCES borrower_aadhaar_kyc_history(id) ON DELETE RESTRICT,
  provider VARCHAR(64) NOT NULL,
  provider_transaction_id VARCHAR(128),
  provider_reference_id BIGINT,
  status VARCHAR(32) NOT NULL,
  provider_message TEXT,
  name VARCHAR(255),
  gender VARCHAR(16),
  date_of_birth VARCHAR(16),
  year_of_birth VARCHAR(8),
  care_of TEXT,
  full_address TEXT,
  country VARCHAR(100),
  district VARCHAR(100),
  house TEXT,
  landmark TEXT,
  pincode VARCHAR(20),
  post_office VARCHAR(100),
  state VARCHAR(100),
  street TEXT,
  subdistrict VARCHAR(100),
  vtc VARCHAR(100),
  email_hash TEXT,
  mobile_hash TEXT,
  raw_response JSONB,
  verified_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS borrower_pan_kyc_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  borrower_profile_id UUID NOT NULL REFERENCES borrower_profiles(id) ON DELETE CASCADE,
  provider VARCHAR(64) NOT NULL,
  provider_transaction_id VARCHAR(128),
  status VARCHAR(32) NOT NULL,
  failure_code VARCHAR(64),
  failure_reason TEXT,
  provider_message TEXT,
  pan_masked VARCHAR(16),
  category VARCHAR(64),
  remarks TEXT,
  name_as_per_pan_match BOOLEAN,
  date_of_birth_match BOOLEAN,
  aadhaar_seeding_status VARCHAR(8),
  raw_response JSONB,
  attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS borrower_pan_kyc_current (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  borrower_profile_id UUID NOT NULL UNIQUE REFERENCES borrower_profiles(id) ON DELETE CASCADE,
  source_history_id UUID NOT NULL REFERENCES borrower_pan_kyc_history(id) ON DELETE RESTRICT,
  provider VARCHAR(64) NOT NULL,
  provider_transaction_id VARCHAR(128),
  status VARCHAR(32) NOT NULL,
  provider_message TEXT,
  pan_masked VARCHAR(16),
  category VARCHAR(64),
  remarks TEXT,
  name_as_per_pan_match BOOLEAN,
  date_of_birth_match BOOLEAN,
  aadhaar_seeding_status VARCHAR(8),
  raw_response JSONB,
  verified_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type consent_type_enum NOT NULL,
  consent_version VARCHAR(32) NOT NULL,
  consent_text TEXT NOT NULL,
  consent_text_hash VARCHAR(128) NOT NULL,
  is_granted BOOLEAN NOT NULL,
  source VARCHAR(64),
  ip_address VARCHAR(64),
  user_agent TEXT,
  metadata JSONB,
  granted_at TIMESTAMP WITH TIME ZONE,
  revoked_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_aadhaar_kyc_history_profile_attempted_at
  ON borrower_aadhaar_kyc_history (borrower_profile_id, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_aadhaar_kyc_history_status_attempted_at
  ON borrower_aadhaar_kyc_history (status, attempted_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_aadhaar_kyc_history_provider_txn
  ON borrower_aadhaar_kyc_history (provider, provider_transaction_id)
  WHERE provider_transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pan_kyc_history_profile_attempted_at
  ON borrower_pan_kyc_history (borrower_profile_id, attempted_at DESC);

CREATE INDEX IF NOT EXISTS idx_pan_kyc_history_status_attempted_at
  ON borrower_pan_kyc_history (status, attempted_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pan_kyc_history_provider_txn
  ON borrower_pan_kyc_history (provider, provider_transaction_id)
  WHERE provider_transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_consents_user_type_created_at
  ON user_consents (user_id, consent_type, created_at DESC);

COMMIT;
