BEGIN;

DROP INDEX IF EXISTS idx_dst_profiles_branch_id;
DROP TABLE IF EXISTS dst_profiles;

ALTER TABLE bank_branches
  DROP COLUMN IF EXISTS dst_commission;

COMMIT;
