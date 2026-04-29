CREATE TABLE payment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    razorpay_order_id VARCHAR(255) UNIQUE NOT NULL,
    loan_id UUID NOT NULL REFERENCES loans(id),
    emi_schedule_id UUID REFERENCES emi_schedules(id),
    amount NUMERIC(15,2) NOT NULL,
    status payment_status NOT NULL DEFAULT 'PENDING',
    razorpay_payment_id VARCHAR(255),
    razorpay_signature VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payment_orders_razorpay_order_id ON payment_orders(razorpay_order_id);
