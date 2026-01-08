-- Payment Intent table for booking payments
-- Designed to be replaceable with real payment gateway later

-- Create enum type for payment intent status
CREATE TYPE payment_intent_status AS ENUM (
    'CREATED',
    'SUCCEEDED',
    'FAILED'
);

-- Create payment_intent table
CREATE TABLE payment_intent (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES booking(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    currency TEXT NOT NULL DEFAULT 'VND',
    status payment_intent_status NOT NULL DEFAULT 'CREATED',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Check constraints
    CONSTRAINT ck_payment_intent_amount_positive CHECK (amount > 0),
    CONSTRAINT ck_payment_intent_currency_not_empty CHECK (currency IS NOT NULL AND length(currency) > 0)
);

-- Create indexes
CREATE INDEX idx_payment_intent_booking_id ON payment_intent(booking_id);
CREATE INDEX idx_payment_intent_status ON payment_intent(status);
CREATE INDEX idx_payment_intent_created_at ON payment_intent(created_at DESC);

-- Trigger to update updated_at on row update
CREATE OR REPLACE FUNCTION update_payment_intent_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_payment_intent_updated_at
    BEFORE UPDATE ON payment_intent
    FOR EACH ROW
    EXECUTE FUNCTION update_payment_intent_updated_at();

-- Comments
COMMENT ON TABLE payment_intent IS 'Payment intents for bookings. Can be replaced with real payment gateway integration later.';
COMMENT ON COLUMN payment_intent.status IS 'CREATED (intent created), SUCCEEDED (payment successful), FAILED (payment failed)';
COMMENT ON COLUMN payment_intent.amount IS 'Amount in smallest currency unit (e.g., VND cents, but stored as integer)';
COMMENT ON COLUMN payment_intent.booking_id IS 'One-to-one relationship with booking (UNIQUE constraint)';

