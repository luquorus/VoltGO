-- Step 1: Delete CRs referencing BS versions of stations without trust
DELETE FROM battery_swap_change_request
WHERE proposed_version_id IN (
    SELECT bssv.id FROM station s
    JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
    LEFT JOIN battery_swap_trust t ON s.id = t.station_id
    WHERE t.id IS NULL
);

-- Step 2: Delete pile templates
DELETE FROM battery_swap_pile_template
WHERE station_version_id IN (
    SELECT bssv.id FROM station s
    JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
    LEFT JOIN battery_swap_trust t ON s.id = t.station_id
    WHERE t.id IS NULL
);

-- Step 3: Delete BS versions
DELETE FROM battery_swap_station_version
WHERE station_id IN (
    SELECT s.id FROM station s
    JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
    LEFT JOIN battery_swap_trust t ON s.id = t.station_id
    WHERE t.id IS NULL
);

-- Step 4: Delete station versions
DELETE FROM station_version
WHERE station_id IN (
    SELECT s.id FROM station s
    JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
    LEFT JOIN battery_swap_trust t ON s.id = t.station_id
    WHERE t.id IS NULL
);

-- Step 5: Delete station state
DELETE FROM battery_swap_station_state
WHERE station_id IN (
    SELECT s.id FROM station s
    JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
    LEFT JOIN battery_swap_trust t ON s.id = t.station_id
    WHERE t.id IS NULL
);

-- Step 6: Delete swap piles (cascade deletes battery slots)
DELETE FROM swap_pile
WHERE station_id IN (
    SELECT s.id FROM station s
    JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
    LEFT JOIN battery_swap_trust t ON s.id = t.station_id
    WHERE t.id IS NULL
);

-- Step 7: Delete stations
DELETE FROM station
WHERE id IN (
    SELECT s.id FROM station s
    JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
    LEFT JOIN battery_swap_trust t ON s.id = t.station_id
    WHERE t.id IS NULL
);

-- Verify
SELECT
    COUNT(DISTINCT s.id) AS total_bs_stations,
    COUNT(DISTINCT t.id) AS stations_with_trust,
    COUNT(DISTINCT s.id) - COUNT(DISTINCT t.id) AS stations_without_trust
FROM station s
JOIN battery_swap_station_version bssv ON s.id = bssv.station_id
LEFT JOIN battery_swap_trust t ON s.id = t.station_id;
