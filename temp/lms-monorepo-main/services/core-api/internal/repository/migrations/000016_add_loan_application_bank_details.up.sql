ALTER TABLE loan_applications 
ADD COLUMN disbursement_account_number VARCHAR(50),
ADD COLUMN disbursement_ifsc_code VARCHAR(20),
ADD COLUMN disbursement_bank_name VARCHAR(100),
ADD COLUMN disbursement_account_holder_name VARCHAR(255);
