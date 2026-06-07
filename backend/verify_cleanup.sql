-- Check for orphaned BS versions (BS versions without a matching trust record)
SELECT COUNT(*) AS orphaned_bs_versions
FROM battery_swap_station_version bssv
LEFT JOIN battery_swap_trust t ON bssv.station_id = t.station_id
WHERE t.id IS NULL;

-- Check for orphaned stations (stations with BS versions but no trust)
SELECT COUNT(*) AS orphaned_stations
FROM station s
JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
LEFT JOIN battery_swap_trust t ON s.id = t.station_id
WHERE t.id IS NULL;

-- List any remaining stations without trust
SELECT s.id, sv.name
FROM station s
JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
LEFT JOIN battery_swap_trust t ON s.id = t.station_id
LEFT JOIN LATERAL (
    SELECT name FROM station_version sv2
    WHERE sv2.station_id = s.id AND sv2.workflow_status = 'PUBLISHED'
    LIMIT 1
) sv ON TRUE
WHERE t.id IS NULL;

-- Summary of all battery swap data
SELECT 'station' AS table_name, COUNT(*) AS row_count FROM station
UNION ALL
SELECT 'station_version', COUNT(*) FROM station_version
UNION ALL
SELECT 'battery_swap_station_version', COUNT(*) FROM battery_swap_station_version
UNION ALL
SELECT 'battery_swap_station_state', COUNT(*) FROM battery_swap_station_state
UNION ALL
SELECT 'battery_swap_trust', COUNT(*) FROM battery_swap_trust
UNION ALL
SELECT 'swap_pile', COUNT(*) FROM swap_pile
UNION ALL
SELECT 'battery_slot', COUNT(*) FROM battery_slot
UNION ALL
SELECT 'battery_swap_change_request', COUNT(*) FROM battery_swap_change_request
UNION ALL
SELECT 'battery_swap_pile_template', COUNT(*) FROM battery_swap_pile_template;
