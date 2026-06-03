-- V123: Delete all existing battery swap station data
-- Cleans up all battery swap related data to allow clean re-seeding.
-- Note: many tables have CASCADE DELETE from station, so explicit deletes
-- are only needed for topologically independent child tables first.

-- Delete battery swap device records (has FK to station)
DELETE FROM battery_swap_station_device
WHERE station_id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete trust records (has FK to station)
DELETE FROM battery_swap_trust
WHERE station_id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete change requests (has FK to station)
DELETE FROM battery_swap_change_request
WHERE station_id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete battery events for battery swap slots (no FK to station, but to battery_slot)
DELETE FROM battery_event
WHERE battery_slot_id IN (
    SELECT bs.id
    FROM battery_slot bs
    JOIN swap_pile sp ON sp.id = bs.pile_id
    JOIN station_version sv ON sv.station_id = sp.station_id
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete charging sessions for battery swap slots
DELETE FROM charging_session
WHERE battery_slot_id IN (
    SELECT bs.id
    FROM battery_slot bs
    JOIN swap_pile sp ON sp.id = bs.pile_id
    JOIN station_version sv ON sv.station_id = sp.station_id
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete swap reservations (swap_payment and swap_session have CASCADE from reservation,
-- so they are auto-deleted; explicit delete needed for battery_swap_reservation itself)
DELETE FROM battery_swap_reservation
WHERE station_id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete battery slots for battery swap piles
DELETE FROM battery_slot
WHERE pile_id IN (
    SELECT p.id
    FROM swap_pile p
    JOIN station_version sv ON sv.station_id = p.station_id
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete swap piles
DELETE FROM swap_pile
WHERE station_id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete battery swap station state (CASCADE from station, but explicit for safety)
DELETE FROM battery_swap_station_state
WHERE station_id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete station_service for battery swap
DELETE FROM station_service
WHERE station_version_id IN (
    SELECT sv.id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete station_version for battery swap stations
DELETE FROM station_version
WHERE station_id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);

-- Delete station records for battery swap stations
DELETE FROM station
WHERE id IN (
    SELECT DISTINCT sv.station_id
    FROM station_version sv
    JOIN station_service ss ON ss.station_version_id = sv.id
    WHERE ss.service_type = 'BATTERY_SWAP'
);
