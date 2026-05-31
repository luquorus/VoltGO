-- V110: Hoàn thiện trạm đổi pin
--
-- Phần 1: Thêm cấu hình đổi pin vào station_service để config đi cùng version (dùng cho CR + verification).
-- Phần 2: Thêm pricing và payment status vào battery_swap_reservation cho phí cố định 5.000đ/lượt.

-- =====================================================================
-- 1. Cấu hình swap đi cùng station_version qua station_service
-- =====================================================================

ALTER TABLE station_service
    ADD COLUMN total_batteries INTEGER,
    ADD COLUMN avg_charge_power_kw NUMERIC(8, 2);

-- Backfill cho các row swap hiện có: lấy từ battery_swap_station_state nếu có, fallback (20, 35.0).
UPDATE station_service ss
SET total_batteries = COALESCE(state.total_batteries, 20),
    avg_charge_power_kw = COALESCE(state.avg_charge_power_kw, 35.0)
FROM station_version sv
LEFT JOIN battery_swap_station_state state ON state.station_id = sv.station_id
WHERE ss.station_version_id = sv.id
  AND ss.service_type = 'BATTERY_SWAP';

-- Constraint: row có service_type=BATTERY_SWAP buộc phải có total_batteries > 0 và avg_charge_power_kw > 0.
-- Row CHARGING giữ nguyên (NULL được phép).
ALTER TABLE station_service
    ADD CONSTRAINT ck_station_service_swap_config CHECK (
        service_type <> 'BATTERY_SWAP'
        OR (
            total_batteries IS NOT NULL
            AND total_batteries > 0
            AND avg_charge_power_kw IS NOT NULL
            AND avg_charge_power_kw > 0
        )
    );

COMMENT ON COLUMN station_service.total_batteries IS 'Tổng số pin tại trạm (chỉ dùng khi service_type=BATTERY_SWAP)';
COMMENT ON COLUMN station_service.avg_charge_power_kw IS 'Công suất sạc trung bình kW dùng để ước tính thời gian (chỉ dùng khi service_type=BATTERY_SWAP)';

-- =====================================================================
-- 2. Pricing & Payment cho battery_swap_reservation
-- =====================================================================

ALTER TABLE battery_swap_reservation
    ADD COLUMN base_price_vnd BIGINT NOT NULL DEFAULT 5000,
    ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'UNPAID';

ALTER TABLE battery_swap_reservation
    ADD CONSTRAINT ck_battery_swap_payment_status CHECK (
        payment_status IN ('UNPAID', 'PAID', 'REFUNDED')
    ),
    ADD CONSTRAINT ck_battery_swap_price_non_negative CHECK (base_price_vnd >= 0);

CREATE INDEX idx_battery_swap_reservation_payment_status
    ON battery_swap_reservation(payment_status);

-- Đồng bộ paymentStatus với reservation đã COMPLETED trước đó: coi như đã PAID.
UPDATE battery_swap_reservation
SET payment_status = 'PAID'
WHERE status = 'COMPLETED'
  AND payment_status = 'UNPAID';

COMMENT ON COLUMN battery_swap_reservation.base_price_vnd IS 'Snapshot phí cơ bản (VND) tại thời điểm đặt; mặc định 5000.';
COMMENT ON COLUMN battery_swap_reservation.payment_status IS 'Trạng thái thanh toán: UNPAID -> PAID khi confirm; REFUNDED khi cancel sau khi đã PAID.';
