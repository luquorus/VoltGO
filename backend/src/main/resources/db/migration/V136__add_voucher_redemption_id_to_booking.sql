-- V136: Add voucher redemption fields to booking and payment_intent tables
-- Supports linking voucher redemptions to bookings and payment intents for discount application

-- Add voucher_redemption_id to booking table
ALTER TABLE booking
ADD COLUMN voucher_redemption_id UUID;

CREATE INDEX idx_booking_voucher_redemption_id ON booking(voucher_redemption_id);

-- Add voucher redemption fields to payment_intent table
ALTER TABLE payment_intent
ADD COLUMN voucher_redemption_id UUID;

ALTER TABLE payment_intent
ADD COLUMN discount_amount INTEGER;
