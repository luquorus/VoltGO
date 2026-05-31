-- V118: Fix V109 FK và V112 created_at
--
-- Phần 1: V109 — battery_swap_station_state có PRIMARY KEY = station_id nhưng không có
--   FK ràng buộc với bảng station. Entity cũng không có @ManyToOne — thêm FK constraint.
--
-- Phần 2: V112 — bảng swap_pile thiếu created_at mà Entity có.
--   (battery_slot cũng thiếu created_at nhưng Entity không dùng nên bỏ qua.)

-- =====================================================================
-- 1. Thêm FK constraint cho battery_swap_station_state.station_id
-- =====================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
         AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_name = 'battery_swap_station_state'
          AND kcu.column_name = 'station_id'
    ) THEN
        ALTER TABLE battery_swap_station_state
            ADD CONSTRAINT fk_battery_swap_station_state_station
            FOREIGN KEY (station_id) REFERENCES station(id) ON DELETE CASCADE;
    END IF;
END $$;

COMMENT ON TABLE battery_swap_station_state
    IS 'Trạng thái kho pin của trạm đổi pin. FK: station_id -> station(id).';

COMMENT ON COLUMN battery_swap_station_state.station_id
    IS 'FK -> station(id). PK của bảng này cũng là station_id.';

COMMENT ON COLUMN battery_swap_station_state.total_batteries
    IS 'Tổng số pin tại trạm.';

COMMENT ON COLUMN battery_swap_station_state.available_batteries
    IS 'Số pin đang AVAILABLE (đầy 100%, sẵn sàng đổi cho user).';

COMMENT ON COLUMN battery_swap_station_state.avg_charge_power_kw
    IS 'Công suất sạc trung bình kW dùng để ước tính thời gian sạc.';

COMMENT ON COLUMN battery_swap_station_state.updated_at
    IS 'Thời điểm cập nhật trạng thái gần nhất.';

-- =====================================================================
-- 2. Thêm created_at cho swap_pile (V112 thiếu)
-- =====================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'swap_pile' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE swap_pile
            ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT NOW();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'swap_pile' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE swap_pile
            ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT NOW();
    END IF;
END $$;

-- Set giá trị cho các row hiện có
UPDATE swap_pile SET created_at = NOW() WHERE created_at IS NULL;
UPDATE swap_pile SET updated_at = NOW() WHERE updated_at IS NULL;

-- Make NOT NULL sau khi đã set giá trị
ALTER TABLE swap_pile ALTER COLUMN created_at SET NOT NULL;
ALTER TABLE swap_pile ALTER COLUMN updated_at SET NOT NULL;

COMMENT ON TABLE swap_pile
    IS 'Trụ đổi pin tại trạm. Mỗi trụ chứa nhiều slot pin.';

COMMENT ON COLUMN swap_pile.created_at
    IS 'Thời điểm tạo trụ.';

COMMENT ON COLUMN swap_pile.updated_at
    IS 'Thời điểm cập nhật gần nhất.';

-- =====================================================================
-- 3. Thêm created_at cho battery_slot (V112 thiếu)
-- =====================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'battery_slot' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE battery_slot
            ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT NOW();
    END IF;
END $$;

-- Set giá trị cho các row hiện có
UPDATE battery_slot SET created_at = NOW() WHERE created_at IS NULL;

-- Make NOT NULL
ALTER TABLE battery_slot ALTER COLUMN created_at SET NOT NULL;

COMMENT ON COLUMN battery_slot.created_at
    IS 'Thời điểm tạo slot.';
