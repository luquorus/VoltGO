-- ============================================================
-- V999_04__alter_verification_task_battery_swap.sql
-- Adds battery swap fields to verification_task table
-- ============================================================

ALTER TABLE verification_task
    ADD COLUMN verification_type VARCHAR(20) NOT NULL DEFAULT 'CHARGING_STATION',
    ADD COLUMN battery_swap_change_request_id UUID REFERENCES battery_swap_change_request(id) ON DELETE SET NULL,
    ADD COLUMN battery_swap_station_snapshot JSONB;

COMMENT ON COLUMN verification_task.verification_type IS 'CHARGING_STATION or BATTERY_SWAP';
COMMENT ON COLUMN verification_task.battery_swap_change_request_id IS 'Reference to battery swap change request for battery swap verifications';
COMMENT ON COLUMN verification_task.battery_swap_station_snapshot IS '{"totalBatteries": 20, "avgChargePowerKw": 35, "pileCount": 4, "slotCount": 24, "basePriceVnd": 5000}';
