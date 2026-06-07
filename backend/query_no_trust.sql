-- Find all BS stations that have no trust record
SELECT s.id AS station_id, sv.name AS station_name, t.id AS trust_id
FROM station s
JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
LEFT JOIN battery_swap_trust t ON s.id = t.station_id
LEFT JOIN LATERAL (
    SELECT name FROM station_version sv2
    WHERE sv2.station_id = s.id AND sv2.workflow_status = 'PUBLISHED'
    LIMIT 1
) sv ON TRUE
WHERE t.id IS NULL
GROUP BY s.id, sv.name, t.id
ORDER BY s.id;
