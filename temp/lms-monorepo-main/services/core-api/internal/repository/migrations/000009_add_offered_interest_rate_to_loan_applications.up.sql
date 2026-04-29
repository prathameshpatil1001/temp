ALTER TABLE loan_applications
ADD COLUMN IF NOT EXISTS offered_interest_rate NUMERIC(5,2);

UPDATE loan_applications la
SET offered_interest_rate = lp.base_interest_rate
FROM loan_products lp
WHERE la.loan_product_id = lp.id
  AND la.offered_interest_rate IS NULL;
