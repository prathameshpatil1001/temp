DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'loan_application_status') THEN
        IF EXISTS (SELECT 1 FROM loan_applications WHERE status::text IN (
            'OFFICER_REVIEW',
            'OFFICER_APPROVED',
            'OFFICER_REJECTED',
            'MANAGER_REVIEW',
            'MANAGER_APPROVED',
            'MANAGER_REJECTED'
        )) THEN
            RAISE EXCEPTION 'cannot downgrade: loan_applications has rows using expanded statuses';
        END IF;

        ALTER TYPE loan_application_status RENAME TO loan_application_status_old;

        CREATE TYPE loan_application_status AS ENUM (
            'DRAFT',
            'SUBMITTED',
            'UNDER_REVIEW',
            'APPROVED',
            'REJECTED',
            'DISBURSED',
            'CANCELLED'
        );

        ALTER TABLE loan_applications
            ALTER COLUMN status TYPE loan_application_status
            USING status::text::loan_application_status;

        DROP TYPE loan_application_status_old;
    END IF;
END$$;
