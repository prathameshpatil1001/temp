BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'user_role' AND e.enumlabel = 'dst'
  ) THEN
    ALTER TYPE user_role ADD VALUE 'dst';
  END IF;
END $$;

ALTER TABLE bank_branches
  ADD COLUMN IF NOT EXISTS dst_commission NUMERIC(5,2) NOT NULL DEFAULT 0;

ALTER TABLE bank_branches
  DROP CONSTRAINT IF EXISTS bank_branches_dst_commission_check;

ALTER TABLE bank_branches
  ADD CONSTRAINT bank_branches_dst_commission_check
  CHECK (dst_commission >= 0 AND dst_commission <= 100);

CREATE TABLE IF NOT EXISTS dst_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  branch_id UUID NOT NULL REFERENCES bank_branches(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dst_profiles_branch_id ON dst_profiles(branch_id);

COMMIT;
