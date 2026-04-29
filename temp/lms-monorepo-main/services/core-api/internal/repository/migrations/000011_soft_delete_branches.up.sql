ALTER TABLE bank_branches
    ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT false;
