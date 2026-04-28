BEGIN;

CREATE SEQUENCE IF NOT EXISTS employee_serial_seq START 1;

ALTER TABLE manager_profiles
  ADD COLUMN IF NOT EXISTS employee_serial BIGINT;

ALTER TABLE officer_profiles
  ADD COLUMN IF NOT EXISTS employee_serial BIGINT;

ALTER TABLE manager_profiles
  ALTER COLUMN employee_serial SET DEFAULT nextval('employee_serial_seq');

ALTER TABLE officer_profiles
  ALTER COLUMN employee_serial SET DEFAULT nextval('employee_serial_seq');

UPDATE manager_profiles
SET employee_serial = nextval('employee_serial_seq')
WHERE employee_serial IS NULL;

UPDATE officer_profiles
SET employee_serial = nextval('employee_serial_seq')
WHERE employee_serial IS NULL;

ALTER TABLE manager_profiles
  ALTER COLUMN employee_serial SET NOT NULL;

ALTER TABLE officer_profiles
  ALTER COLUMN employee_serial SET NOT NULL;

ALTER TABLE manager_profiles
  ADD COLUMN IF NOT EXISTS employee_code CHAR(6) GENERATED ALWAYS AS (LPAD(employee_serial::text, 6, '0')) STORED;

ALTER TABLE officer_profiles
  ADD COLUMN IF NOT EXISTS employee_code CHAR(6) GENERATED ALWAYS AS (LPAD(employee_serial::text, 6, '0')) STORED;

CREATE UNIQUE INDEX IF NOT EXISTS idx_manager_profiles_employee_serial
  ON manager_profiles (employee_serial);

CREATE UNIQUE INDEX IF NOT EXISTS idx_officer_profiles_employee_serial
  ON officer_profiles (employee_serial);

CREATE UNIQUE INDEX IF NOT EXISTS idx_manager_profiles_employee_code
  ON manager_profiles (employee_code);

CREATE UNIQUE INDEX IF NOT EXISTS idx_officer_profiles_employee_code
  ON officer_profiles (employee_code);

COMMIT;
