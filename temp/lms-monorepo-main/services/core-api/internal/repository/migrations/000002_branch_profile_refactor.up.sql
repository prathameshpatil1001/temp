BEGIN;

CREATE TABLE IF NOT EXISTS bank_branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    region VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE manager_profiles ADD COLUMN IF NOT EXISTS name VARCHAR(255);
ALTER TABLE officer_profiles ADD COLUMN IF NOT EXISTS name VARCHAR(255);

ALTER TABLE manager_profiles ADD COLUMN IF NOT EXISTS branch_id UUID;
ALTER TABLE officer_profiles ADD COLUMN IF NOT EXISTS branch_id UUID;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'manager_profiles_branch_id_fkey'
  ) THEN
    ALTER TABLE manager_profiles
      ADD CONSTRAINT manager_profiles_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES bank_branches(id);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'officer_profiles_branch_id_fkey'
  ) THEN
    ALTER TABLE officer_profiles
      ADD CONSTRAINT officer_profiles_branch_id_fkey
      FOREIGN KEY (branch_id) REFERENCES bank_branches(id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'bank_branches'
      AND column_name = 'manager_id'
  ) THEN
    EXECUTE '
      UPDATE manager_profiles mp
      SET branch_id = bb.id
      FROM bank_branches bb
      WHERE bb.manager_id = mp.id
        AND mp.branch_id IS NULL
    ';
  END IF;
END $$;

ALTER TABLE bank_branches DROP COLUMN IF EXISTS manager_id;

CREATE INDEX IF NOT EXISTS idx_manager_profiles_branch_id ON manager_profiles(branch_id);
CREATE INDEX IF NOT EXISTS idx_officer_profiles_branch_id ON officer_profiles(branch_id);

COMMIT;
