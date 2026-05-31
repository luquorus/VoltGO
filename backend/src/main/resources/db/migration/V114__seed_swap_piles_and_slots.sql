-- V114: Seed swap piles and slots for sample battery swap stations
-- This runs AFTER V112 creates the tables

-- =====================================================================
-- Create swap piles and slots for sample stations
-- Station 1: 24 batteries -> 4 piles of 6 slots
-- =====================================================================

-- Station 1: 4 piles (24 batteries = 4 piles x 6 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000001',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000002',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000003',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000004',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Station 2: 16 batteries -> 3 piles (6+6+4 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000002', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000002', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000002', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000011', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000012', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000013', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(0, 3) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Station 3: 20 batteries -> 4 piles (5+5+5+5)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000021', 'f1000000-0000-0000-0000-000000000003', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000022', 'f1000000-0000-0000-0000-000000000003', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000023', 'f1000000-0000-0000-0000-000000000003', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000024', 'f1000000-0000-0000-0000-000000000003', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000021', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000022', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000023', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000024', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Sync available_batteries in battery_swap_station_state to match actual AVAILABLE slot counts.
-- V109 initially set these to 10 for all stations; update them based on real slot data.
UPDATE battery_swap_station_state s
SET available_batteries = sub.cnt,
    updated_at = NOW()
FROM (
    SELECT station_id, COUNT(*) AS cnt
    FROM swap_pile p
    JOIN battery_slot b ON b.pile_id = p.id
    WHERE b.status = 'AVAILABLE'
    GROUP BY station_id
) sub
WHERE s.station_id = sub.station_id;
