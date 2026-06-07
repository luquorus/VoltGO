-- Check station state power settings
SELECT
    station_id,
    total_batteries,
    available_batteries,
    avg_charge_power_kw,
    updated_at
FROM battery_swap_station_state
ORDER BY updated_at DESC
LIMIT 5;
