-- Check slot charge levels
SELECT
    bs.id AS slot_id,
    bs.pile_id,
    bs.battery_charge_percent,
    bs.status,
    bs.charging_started_at,
    bs.estimated_full_at,
    bs.updated_at
FROM battery_slot bs
WHERE bs.status IN ('CHARGING', 'SWAPPED_OUT')
ORDER BY bs.battery_charge_percent DESC
LIMIT 10;
