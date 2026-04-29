BEGIN;

DROP INDEX IF EXISTS idx_officer_profiles_employee_code;
DROP INDEX IF EXISTS idx_manager_profiles_employee_code;
DROP INDEX IF EXISTS idx_officer_profiles_employee_serial;
DROP INDEX IF EXISTS idx_manager_profiles_employee_serial;

ALTER TABLE officer_profiles DROP COLUMN IF EXISTS employee_code;
ALTER TABLE manager_profiles DROP COLUMN IF EXISTS employee_code;

ALTER TABLE officer_profiles ALTER COLUMN employee_serial DROP DEFAULT;
ALTER TABLE manager_profiles ALTER COLUMN employee_serial DROP DEFAULT;

ALTER TABLE officer_profiles DROP COLUMN IF EXISTS employee_serial;
ALTER TABLE manager_profiles DROP COLUMN IF EXISTS employee_serial;

DROP SEQUENCE IF EXISTS employee_serial_seq;

COMMIT;
