BEGIN;

ALTER TABLE bank_branches ADD COLUMN IF NOT EXISTS manager_id UUID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'bank_branches_manager_id_fkey'
  ) THEN
    ALTER TABLE bank_branches
      ADD CONSTRAINT bank_branches_manager_id_fkey
      FOREIGN KEY (manager_id) REFERENCES manager_profiles(id);
  END IF;
END $$;

UPDATE bank_branches bb
SET manager_id = mp.id
FROM manager_profiles mp
WHERE mp.branch_id = bb.id
  AND bb.manager_id IS NULL;

ALTER TABLE manager_profiles DROP CONSTRAINT IF EXISTS manager_profiles_branch_id_fkey;
ALTER TABLE officer_profiles DROP CONSTRAINT IF EXISTS officer_profiles_branch_id_fkey;

DROP INDEX IF EXISTS idx_manager_profiles_branch_id;
DROP INDEX IF EXISTS idx_officer_profiles_branch_id;

ALTER TABLE manager_profiles DROP COLUMN IF EXISTS branch_id;
ALTER TABLE officer_profiles DROP COLUMN IF EXISTS branch_id;

COMMIT;
