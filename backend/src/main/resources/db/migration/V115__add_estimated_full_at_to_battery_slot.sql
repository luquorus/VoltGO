-- V115__add_estimated_full_at_to_battery_slot.sql
-- Thêm column estimated_full_at vào bảng battery_slot
-- Dùng cho tính năng simulation sạc pin

ALTER TABLE battery_slot ADD COLUMN IF NOT EXISTS estimated_full_at TIMESTAMPTZ;
