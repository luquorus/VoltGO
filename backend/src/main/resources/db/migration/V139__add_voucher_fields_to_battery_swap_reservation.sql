-- V139__add_voucher_fields_to_battery_swap_reservation.sql
-- Thêm voucher_redemption_id và discount_amount_vnd vào bảng battery_swap_reservation
-- để hỗ trợ voucher FREE_SERVICE cho battery swap.

ALTER TABLE battery_swap_reservation ADD COLUMN IF NOT EXISTS voucher_redemption_id UUID;
ALTER TABLE battery_swap_reservation ADD COLUMN IF NOT EXISTS discount_amount_vnd INTEGER;

CREATE INDEX IF NOT EXISTS idx_bsr_voucher_redemption_id ON battery_swap_reservation(voucher_redemption_id);
