-- V116__add_confirmed_arrival_at_to_battery_swap_reservation.sql
-- Thêm column confirmed_arrival_at vào bảng battery_swap_reservation
-- Dùng để track thời điểm user xác nhận đã đến trạm

ALTER TABLE battery_swap_reservation ADD COLUMN IF NOT EXISTS confirmed_arrival_at TIMESTAMPTZ;
