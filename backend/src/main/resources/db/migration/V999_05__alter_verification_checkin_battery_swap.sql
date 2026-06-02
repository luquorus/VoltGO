-- ============================================================
-- V999_05__alter_verification_checkin_battery_swap.sql
-- Adds battery swap fields to verification_checkin table
-- ============================================================

ALTER TABLE verification_checkin
    ADD COLUMN actual_total_batteries INTEGER,
    ADD COLUMN actual_available_batteries INTEGER,
    ADD COLUMN observed_avg_charge_power_kw DECIMAL(6,2);

COMMENT ON COLUMN verification_checkin.actual_total_batteries IS 'Actual total battery inventory observed during checkin';
COMMENT ON COLUMN verification_checkin.actual_available_batteries IS 'Actual available batteries at time of checkin';
COMMENT ON COLUMN verification_checkin.observed_avg_charge_power_kw IS 'Observed average charging power in kW';
