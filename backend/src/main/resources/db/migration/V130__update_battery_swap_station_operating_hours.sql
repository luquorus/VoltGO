-- V130__update_battery_swap_station_operating_hours.sql
-- Sets operating_hours = '24/7' for ALL battery swap station versions.
--
-- Target column: battery_swap_station_version.operating_hours
--   VARCHAR(100) NOT NULL  (from V999_01__create_battery_swap_station_version_tables.sql)
--
-- Why: stations created via mobile app CR flow may have been inserted with NULL
-- despite the NOT NULL constraint (or the constraint was not enforced).
-- V125 already seeded '06:00-22:00' etc., but we want '24/7' for all.
-- Safe to re-run (idempotent UPDATE).

-- ============================================================================
-- Update every row: set operating_hours to '24/7'
-- ============================================================================
UPDATE battery_swap_station_version
SET    operating_hours = '24/7';

-- ============================================================================
-- Verification
-- ============================================================================
DO $$
DECLARE
    total_count   INTEGER;
    null_count    INTEGER;
    mismatch_ct   INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_count FROM battery_swap_station_version;
    SELECT COUNT(*) INTO null_count  FROM battery_swap_station_version WHERE operating_hours IS NULL;
    SELECT COUNT(*) INTO mismatch_ct FROM battery_swap_station_version WHERE operating_hours != '24/7';

    RAISE NOTICE '========================================';
    RAISE NOTICE 'battery_swap_station_version summary:';
    RAISE NOTICE '  Total rows:                        %', total_count;
    RAISE NOTICE '  Rows with NULL operating_hours:   %', null_count;
    RAISE NOTICE '  Rows with non-24/7 operating_hours: %', mismatch_ct;
    RAISE NOTICE '========================================';

    IF null_count = 0 AND mismatch_ct = 0 THEN
        RAISE NOTICE 'OK: All % battery_swap_station_version rows have operating_hours = ''24/7''.',
                    total_count;
    ELSE
        RAISE WARNING 'WARNING: Some battery_swap_station_version rows may still have incorrect operating_hours.';
    END IF;
END $$;
