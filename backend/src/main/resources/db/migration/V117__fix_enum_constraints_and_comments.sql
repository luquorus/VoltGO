-- V117: Schema consistency fixes
--
-- Phần 1: V100 — thêm CHECK constraint cho enum charger_unit_status
--   (V100 dùng CREATE TYPE nhưng không thêm CHECK. Entity dùng @Enumerated nên
--   enum là source-of-truth, nhưng DB constraint giúp đảm bảo tính nhất quán.)
--
-- Phần 2: V102 — cập nhật COMMENT cho price_snapshot
--   (V102 chỉ UPDATE comment nhưng không UPDATE cột nào nên Flyway có thể pass
--   nhưng comment thực tế không thay đổi — chỉ cần đảm bảo comment đúng.)

-- =====================================================================
-- 1. CHECK constraint cho charger_unit_status enum
-- =====================================================================

-- Kiểm tra enum tồn tại trước khi thêm constraint
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'charger_unit_status'
    ) THEN
        ALTER TABLE charger_unit
            DROP CONSTRAINT IF EXISTS ck_charger_unit_status_enum;
        ALTER TABLE charger_unit
            ADD CONSTRAINT ck_charger_unit_status_enum
            CHECK (status IN ('ACTIVE', 'INACTIVE', 'MAINTENANCE'));
    END IF;
END $$;

-- =====================================================================
-- 2. Đảm bảo comment cho price_snapshot đúng
-- =====================================================================

COMMENT ON COLUMN booking.price_snapshot
    IS 'JSON snapshot of pricing at booking time: {unitLabel, powerType, powerKw, pricePerSlot, durationMinutes, slotCount, amount}';

COMMENT ON COLUMN booking.charger_unit_id
    IS 'Reference to specific charger unit being booked';

COMMENT ON COLUMN booking.time_range
    IS 'Generated time range for exclusion constraint. Format: [start_time, end_time)';

COMMENT ON CONSTRAINT ck_booking_no_overlap_active ON booking
    IS 'Prevents overlapping bookings on same charger_unit when status is HOLD or CONFIRMED';
