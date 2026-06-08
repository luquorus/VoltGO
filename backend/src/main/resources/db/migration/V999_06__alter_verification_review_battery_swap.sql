-- ============================================================
-- V999_06__alter_verification_review_battery_swap.sql
-- Adds battery swap fields to verification_review table
-- ============================================================

ALTER TABLE verification_review
    ADD COLUMN swap_station_verified BOOLEAN,
    ADD COLUMN inventory_accurate BOOLEAN,
    ADD COLUMN resolution_note TEXT;

COMMENT ON COLUMN verification_review.swap_station_verified IS 'Whether battery swap station was verified as operational';
COMMENT ON COLUMN verification_review.inventory_accurate IS 'Whether battery inventory count was accurate';
COMMENT ON COLUMN verification_review.resolution_note IS 'Note explaining the verification outcome and any discrepancies';
