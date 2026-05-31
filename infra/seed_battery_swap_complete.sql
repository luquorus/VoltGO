-- Complete seed for battery swap stations
-- Run this script to add battery swap stations with swap piles and battery slots
-- Usage:
--   Get-Content infra/seed_battery_swap_complete.sql | docker exec -i voltgo-postgres psql -U voltgo_user -d voltgo
-- Or run through Flyway if using migrations

-- =====================================================================
-- Station 1: Hoan Kiem - Battery Swap Demo
-- Location: 12 Hang Bai, Hoan Kiem, Hanoi
-- UUID: f1000000-0000-0000-0000-000000000001
-- =====================================================================

INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'f2000000-0000-0000-0000-000000000001',
    'f1000000-0000-0000-0000-000000000001',
    1,
    'PUBLISHED',
    'Battery Swap Hoan Kiem Demo',
    '12 Hang Bai, Hoan Kiem, Hanoi',
    ST_SetSRID(ST_MakePoint(105.8545, 21.0288), 4326),
    '24/7',
    'FREE',
    'PUBLIC',
    'ACTIVE',
    '20000000-0000-0000-0000-000000000001',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES (
    'f3000000-0000-0000-0000-000000000001',
    'f2000000-0000-0000-0000-000000000001',
    'BATTERY_SWAP',
    24,
    40.0
)
ON CONFLICT (id) DO UPDATE SET
    total_batteries = EXCLUDED.total_batteries,
    avg_charge_power_kw = EXCLUDED.avg_charge_power_kw;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000001', 24, 12, 40.0, NOW())
ON CONFLICT (station_id) DO UPDATE SET
    total_batteries = EXCLUDED.total_batteries,
    available_batteries = EXCLUDED.available_batteries,
    avg_charge_power_kw = EXCLUDED.avg_charge_power_kw,
    updated_at = NOW();

-- Station 1: 4 piles (24 batteries = 4 piles x 6 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert 6 slots for Pile 1
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000001',
    s.slot_idx,
    90 + floor(random() * 11)::int,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 6 slots for Pile 2
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000002',
    s.slot_idx,
    90 + floor(random() * 11)::int,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 6 slots for Pile 3
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000003',
    s.slot_idx,
    85 + floor(random() * 16)::int,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 6 slots for Pile 4
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000004',
    s.slot_idx,
    80 + floor(random() * 21)::int,
    'AVAILABLE',
    NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- Station 2: Ba Dinh - Battery Swap Demo
-- Location: 2 Lieu Giai, Ba Dinh, Hanoi
-- UUID: f1000000-0000-0000-0000-000000000002
-- =====================================================================

INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'f2000000-0000-0000-0000-000000000002',
    'f1000000-0000-0000-0000-000000000002',
    1,
    'PUBLISHED',
    'Battery Swap Ba Dinh Demo',
    '2 Lieu Giai, Ba Dinh, Hanoi',
    ST_SetSRID(ST_MakePoint(105.8120, 21.0355), 4326),
    '06:00-22:00',
    'PAID',
    'PUBLIC',
    'ACTIVE',
    '20000000-0000-0000-0000-000000000001',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES (
    'f3000000-0000-0000-0000-000000000002',
    'f2000000-0000-0000-0000-000000000002',
    'BATTERY_SWAP',
    16,
    35.0
)
ON CONFLICT (id) DO UPDATE SET
    total_batteries = EXCLUDED.total_batteries,
    avg_charge_power_kw = EXCLUDED.avg_charge_power_kw;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000002', 16, 8, 35.0, NOW())
ON CONFLICT (station_id) DO UPDATE SET
    total_batteries = EXCLUDED.total_batteries,
    available_batteries = EXCLUDED.available_batteries,
    avg_charge_power_kw = EXCLUDED.avg_charge_power_kw,
    updated_at = NOW();

-- Station 2: 3 piles (16 batteries = 6+6+4 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000002', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000002', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000002', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert 6 slots for Pile 1
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000011', s.slot_idx,
       70 + floor(random() * 31)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 6 slots for Pile 2
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000012', s.slot_idx,
       70 + floor(random() * 31)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 4 slots for Pile 3
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000013', s.slot_idx,
       70 + floor(random() * 31)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 3) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- Station 3: Cau Giay - Battery Swap Demo
-- Location: 100 Xuan Thuy, Cau Giay, Hanoi
-- UUID: f1000000-0000-0000-0000-000000000003
-- =====================================================================

INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'f2000000-0000-0000-0000-000000000003',
    'f1000000-0000-0000-0000-000000000003',
    1,
    'PUBLISHED',
    'Battery Swap Cau Giay Demo',
    '100 Xuan Thuy, Cau Giay, Hanoi',
    ST_SetSRID(ST_MakePoint(105.7850, 21.0380), 4326),
    '24/7',
    'FREE',
    'PUBLIC',
    'ACTIVE',
    '20000000-0000-0000-0000-000000000001',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES (
    'f3000000-0000-0000-0000-000000000003',
    'f2000000-0000-0000-0000-000000000003',
    'BATTERY_SWAP',
    20,
    35.0
)
ON CONFLICT (id) DO UPDATE SET
    total_batteries = EXCLUDED.total_batteries,
    avg_charge_power_kw = EXCLUDED.avg_charge_power_kw;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000003', 20, 15, 35.0, NOW())
ON CONFLICT (station_id) DO UPDATE SET
    total_batteries = EXCLUDED.total_batteries,
    available_batteries = EXCLUDED.available_batteries,
    avg_charge_power_kw = EXCLUDED.avg_charge_power_kw,
    updated_at = NOW();

-- Station 3: 4 piles (20 batteries = 5+5+5+5 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000021', 'f1000000-0000-0000-0000-000000000003', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000022', 'f1000000-0000-0000-0000-000000000003', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000023', 'f1000000-0000-0000-0000-000000000003', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000024', 'f1000000-0000-0000-0000-000000000003', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert 5 slots for Pile 1
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000021', s.slot_idx,
       80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 5 slots for Pile 2
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000022', s.slot_idx,
       80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 5 slots for Pile 3
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000023', s.slot_idx,
       80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Insert 5 slots for Pile 4
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000024', s.slot_idx,
       80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- Verify data
-- =====================================================================
SELECT 'Battery Swap Stations' AS info, COUNT(*) AS count FROM station_version sv
JOIN station_service ss ON ss.station_version_id = sv.id
WHERE ss.service_type = 'BATTERY_SWAP' AND sv.workflow_status = 'PUBLISHED';

SELECT 'Swap Piles' AS info, COUNT(*) AS count FROM swap_pile;

SELECT 'Battery Slots' AS info, COUNT(*) AS count FROM battery_slot;

SELECT 'Available Battery Slots' AS info, COUNT(*) AS count FROM battery_slot WHERE status = 'AVAILABLE';
