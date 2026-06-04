-- V131__update_battery_swap_station_operating_hours.sql
-- Sets operating_hours = '24/7' for ALL battery swap station versions.
-- Target: battery_swap_station_version.operating_hours (VARCHAR(100) NOT NULL)
--
-- This migration is needed because:
--   1. battery_swap_station_version table was created by V999_01
--   2. Stations seeded in V124/V125 inserted rows with varied operating_hours
--   3. Stations created via mobile app CR may have been inserted without operating_hours
-- All battery swap stations should operate 24/7.

UPDATE battery_swap_station_version
SET    operating_hours = '24/7'
WHERE  operating_hours IS NULL
   OR  operating_hours = ''
   OR  operating_hours != '24/7';
