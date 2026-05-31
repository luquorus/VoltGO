-- Remove unused target_battery_percent column from battery_swap_reservation
-- The swap station charges the user's old battery to 100%, so targetBatteryPercent is not needed

ALTER TABLE battery_swap_reservation DROP COLUMN IF EXISTS target_battery_percent;
