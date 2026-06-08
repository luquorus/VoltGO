-- V124: Seed 20 Battery Swap stations across Hanoi landmarks
-- Safe to re-run: uses ON CONFLICT DO NOTHING for idempotency.
--
-- Provider ID: 20000000-0000-0000-0000-000000000001 (VoltGo Demo Provider)

-- =============================================================================
-- STATION 1: Hoan Kiem Lake
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000010', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000010',
    'f1000000-0000-0000-0000-000000000010',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Hồ Hoàn Kiếm',
    'Hồ Hoàn Kiếm, Hoàn Kiếm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.85202, 21.02851), 4326),
    '06:00-22:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000010', 'f2000000-0000-0000-0000-000000000010', 'BATTERY_SWAP', 24, 40.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000010', 24, 20, 40.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

-- Piles & Slots (4 piles x 6 = 24 batteries)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000100', 'f1000000-0000-0000-0000-000000000010', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000101', 'f1000000-0000-0000-0000-000000000010', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000102', 'f1000000-0000-0000-0000-000000000010', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000103', 'f1000000-0000-0000-0000-000000000010', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000100', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000101', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000102', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000103', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 2: Den Ngoc Son (Temple of Jade Mountain)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000011', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000011',
    'f1000000-0000-0000-0000-000000000011',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Đền Ngọc Sơn',
    'Đền Ngọc Sơn, Hồ Hoàn Kiếm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.85247, 21.02963), 4326),
    '07:00-21:00', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000011', 'f2000000-0000-0000-0000-000000000011', 'BATTERY_SWAP', 16, 35.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000011', 16, 12, 35.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000110', 'f1000000-0000-0000-0000-000000000011', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000111', 'f1000000-0000-0000-0000-000000000011', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000112', 'f1000000-0000-0000-0000-000000000011', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000110', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000111', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000112', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 3) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 3: Nha Hat Lon Hanoi (Hanoi Opera House)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000012', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000012',
    'f1000000-0000-0000-0000-000000000012',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Nhà hát Lớn Hà Nội',
    'Số 1 Tràng Tiền, Hoàn Kiếm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.85755, 21.02449), 4326),
    '06:00-23:00', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000012', 'f2000000-0000-0000-0000-000000000012', 'BATTERY_SWAP', 20, 38.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000012', 20, 15, 38.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000120', 'f1000000-0000-0000-0000-000000000012', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000121', 'f1000000-0000-0000-0000-000000000012', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000122', 'f1000000-0000-0000-0000-000000000012', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000123', 'f1000000-0000-0000-0000-000000000012', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000120', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000121', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000122', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000123', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 2) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 4: Van Mieu - Quoc Tu Giam (Temple of Literature)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000013', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000013',
    'f1000000-0000-0000-0000-000000000013',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Văn Miếu Quốc Tử Giám',
    'Quốc Tử Giám, Đường Quốc Tử Giám, Văn Miếu, Đống Đa, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83564, 21.02808), 4326),
    '07:00-18:00', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000013', 'f2000000-0000-0000-0000-000000000013', 'BATTERY_SWAP', 18, 35.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000013', 18, 14, 35.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000130', 'f1000000-0000-0000-0000-000000000013', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000131', 'f1000000-0000-0000-0000-000000000013', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000132', 'f1000000-0000-0000-0000-000000000013', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000130', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000131', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000132', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 5: Lang Chu Tich Ho Chi Minh (Ho Chi Minh Mausoleum)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000014', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000014',
    'f1000000-0000-0000-0000-000000000014',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Lăng Chủ tịch Hồ Chí Minh',
    'Hà Nội, Ba Đình, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83474, 21.03683), 4326),
    '08:00-17:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000014', 'f2000000-0000-0000-0000-000000000014', 'BATTERY_SWAP', 12, 38.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000014', 12, 10, 38.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000140', 'f1000000-0000-0000-0000-000000000014', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000141', 'f1000000-0000-0000-0000-000000000014', 2, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000140', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000141', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 6: Chua Mot Cot (One Pillar Pagoda)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000015', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000015',
    'f1000000-0000-0000-0000-000000000015',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Chùa Một Cột',
    'Chùa Một Cột, Ba Đình, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83360, 21.03583), 4326),
    '07:00-18:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000015', 'f2000000-0000-0000-0000-000000000015', 'BATTERY_SWAP', 12, 35.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000015', 12, 9, 35.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000150', 'f1000000-0000-0000-0000-000000000015', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000151', 'f1000000-0000-0000-0000-000000000015', 2, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000150', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000151', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 7: Hoang Thanh Thang Long (Thang Long Imperial Citadel)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000016', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000016',
    'f1000000-0000-0000-0000-000000000016',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Hoàng Thành Thăng Long',
    'Hoàng Thành Thăng Long, Ba Đình, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83678, 21.03708), 4326),
    '08:00-17:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000016', 'f2000000-0000-0000-0000-000000000016', 'BATTERY_SWAP', 16, 38.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000016', 16, 13, 38.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000160', 'f1000000-0000-0000-0000-000000000016', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000161', 'f1000000-0000-0000-0000-000000000016', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000162', 'f1000000-0000-0000-0000-000000000016', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000160', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000161', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000162', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 3) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 8: Cot Co Ha Noi (Hanoi Flag Tower)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000017', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000017',
    'f1000000-0000-0000-0000-000000000017',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Cột Cờ Hà Nội',
    'Cột Cờ Hà Nội, Ba Đình, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83725, 21.03495), 4326),
    '07:00-17:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000017', 'f2000000-0000-0000-0000-000000000017', 'BATTERY_SWAP', 12, 35.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000017', 12, 9, 35.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000170', 'f1000000-0000-0000-0000-000000000017', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000171', 'f1000000-0000-0000-0000-000000000017', 2, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000170', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000171', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 9: Nha Tu Hoa Lo (Hoa Lo Prison)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000018', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000018',
    'f1000000-0000-0000-0000-000000000018',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Nhà tù Hỏa Lò',
    'Nhà tù Hỏa Lò, Hoàn Kiếm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.84716, 21.02561), 4326),
    '08:00-17:30', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000018', 'f2000000-0000-0000-0000-000000000018', 'BATTERY_SWAP', 16, 35.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000018', 16, 12, 35.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000180', 'f1000000-0000-0000-0000-000000000018', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000181', 'f1000000-0000-0000-0000-000000000018', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000182', 'f1000000-0000-0000-0000-000000000018', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000180', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000181', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000182', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 3) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 10: Ho Tay (West Lake)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000019', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000019',
    'f1000000-0000-0000-0000-000000000019',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Hồ Tây',
    'Hồ Tây, Tây Hồ, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.81881, 21.05561), 4326),
    '24/7', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000019', 'f2000000-0000-0000-0000-000000000019', 'BATTERY_SWAP', 24, 42.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000019', 24, 18, 42.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000190', 'f1000000-0000-0000-0000-000000000019', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000191', 'f1000000-0000-0000-0000-000000000019', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000192', 'f1000000-0000-0000-0000-000000000019', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000193', 'f1000000-0000-0000-0000-000000000019', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000190', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000191', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000192', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000193', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 11: Chua Tran Quoc (Tran Quoc Pagoda)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-00000000001a', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-00000000001a',
    'f1000000-0000-0000-0000-00000000001a',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Chùa Trấn Quốc',
    'Chùa Trấn Quốc, Tây Hồ, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83677, 21.04785), 4326),
    '06:00-21:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-00000000001a', 'f2000000-0000-0000-0000-00000000001a', 'BATTERY_SWAP', 18, 38.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-00000000001a', 18, 14, 38.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-0000000001a0', 'f1000000-0000-0000-0000-00000000001a', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001a1', 'f1000000-0000-0000-0000-00000000001a', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001a2', 'f1000000-0000-0000-0000-00000000001a', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001a0', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001a1', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001a2', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 12: Den Quan Thanh (Quan Thanh Temple)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-00000000001b', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-00000000001b',
    'f1000000-0000-0000-0000-00000000001b',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Đền Quán Thánh',
    'Đền Quán Thánh, Ba Đình, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83948, 21.04346), 4326),
    '07:00-18:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-00000000001b', 'f2000000-0000-0000-0000-00000000001b', 'BATTERY_SWAP', 16, 35.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-00000000001b', 16, 12, 35.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-0000000001b0', 'f1000000-0000-0000-0000-00000000001b', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001b1', 'f1000000-0000-0000-0000-00000000001b', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001b2', 'f1000000-0000-0000-0000-00000000001b', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001b0', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001b1', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001b2', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 3) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 13: Cau Long Bien (Long Bien Bridge)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-00000000001c', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-00000000001c',
    'f1000000-0000-0000-0000-00000000001c',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Cầu Long Biên',
    'Cầu Long Biên, Long Biên, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.86495, 21.04384), 4326),
    '24/7', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-00000000001c', 'f2000000-0000-0000-0000-00000000001c', 'BATTERY_SWAP', 20, 38.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-00000000001c', 20, 16, 38.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-0000000001c0', 'f1000000-0000-0000-0000-00000000001c', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001c1', 'f1000000-0000-0000-0000-00000000001c', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001c2', 'f1000000-0000-0000-0000-00000000001c', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001c3', 'f1000000-0000-0000-0000-00000000001c', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001c0', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001c1', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001c2', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001c3', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 2) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 14: Bao Tang Dan Toc Hoc Viet Nam (Vietnam Museum of Ethnology)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-00000000001d', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-00000000001d',
    'f1000000-0000-0000-0000-00000000001d',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Bảo tàng Dân tộc học Việt Nam',
    'Ngõ 187, Đường Nguyễn Xiễn, Bắc Từ Liêm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.79821, 21.04055), 4326),
    '08:30-17:30', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-00000000001d', 'f2000000-0000-0000-0000-00000000001d', 'BATTERY_SWAP', 16, 35.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-00000000001d', 16, 12, 35.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-0000000001d0', 'f1000000-0000-0000-0000-00000000001d', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001d1', 'f1000000-0000-0000-0000-00000000001d', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001d2', 'f1000000-0000-0000-0000-00000000001d', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001d0', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001d1', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001d2', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 15: Bao Tang Ho Chi Minh (Ho Chi Minh Museum)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-00000000001e', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-00000000001e',
    'f1000000-0000-0000-0000-00000000001e',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Bảo tàng Hồ Chí Minh',
    'Bảo tàng Hồ Chí Minh, Ba Đình, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.83273, 21.03616), 4326),
    '08:00-17:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-00000000001e', 'f2000000-0000-0000-0000-00000000001e', 'BATTERY_SWAP', 18, 38.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-00000000001e', 18, 14, 38.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-0000000001e0', 'f1000000-0000-0000-0000-00000000001e', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001e1', 'f1000000-0000-0000-0000-00000000001e', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001e2', 'f1000000-0000-0000-0000-00000000001e', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001e0', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001e1', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001e2', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 16: Cong Vien Thong Nhat (Thong Nhat Park)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-00000000001f', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-00000000001f',
    'f1000000-0000-0000-0000-00000000001f',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Công viên Thống Nhất',
    'Công viên Thống Nhất, Hai Bà Trưng, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.84603, 21.01597), 4326),
    '06:00-22:00', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-00000000001f', 'f2000000-0000-0000-0000-00000000001f', 'BATTERY_SWAP', 20, 38.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-00000000001f', 20, 15, 38.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-0000000001f0', 'f1000000-0000-0000-0000-00000000001f', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001f1', 'f1000000-0000-0000-0000-00000000001f', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001f2', 'f1000000-0000-0000-0000-00000000001f', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-0000000001f3', 'f1000000-0000-0000-0000-00000000001f', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001f0', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001f1', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001f2', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-0000000001f3', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 2) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 17: Keangnam Landmark 72
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000020', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000020',
    'f1000000-0000-0000-0000-000000000020',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Keangnam Landmark 72',
    'Keangnam Landmark 72, Nam Từ Liêm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.78499, 21.01666), 4326),
    '24/7', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000020', 'f2000000-0000-0000-0000-000000000020', 'BATTERY_SWAP', 24, 45.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000020', 24, 20, 45.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000200', 'f1000000-0000-0000-0000-000000000020', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000201', 'f1000000-0000-0000-0000-000000000020', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000202', 'f1000000-0000-0000-0000-000000000020', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000203', 'f1000000-0000-0000-0000-000000000020', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000200', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000201', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000202', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000203', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 18: Lotte Observation Deck
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000021', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000021',
    'f1000000-0000-0000-0000-000000000021',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Lotte Observation Deck',
    'Lotte Center, Thanh Xuân, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.81308, 21.03377), 4326),
    '09:00-22:00', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000021', 'f2000000-0000-0000-0000-000000000021', 'BATTERY_SWAP', 20, 42.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000021', 20, 16, 42.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000210', 'f1000000-0000-0000-0000-000000000021', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000211', 'f1000000-0000-0000-0000-000000000021', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000212', 'f1000000-0000-0000-0000-000000000021', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000213', 'f1000000-0000-0000-0000-000000000021', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000210', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000211', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000212', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000213', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 2) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 19: Vincom Center Ba Trieu
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000022', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000022',
    'f1000000-0000-0000-0000-000000000022',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Vincom Center Bà Triệu',
    'Vincom Center Bà Triệu, Hai Bà Trưng, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.84952, 21.01272), 4326),
    '10:00-22:00', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000022', 'f2000000-0000-0000-0000-000000000022', 'BATTERY_SWAP', 20, 40.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000022', 20, 16, 40.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000220', 'f1000000-0000-0000-0000-000000000022', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000221', 'f1000000-0000-0000-0000-000000000022', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000222', 'f1000000-0000-0000-0000-000000000022', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000223', 'f1000000-0000-0000-0000-000000000022', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000220', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000221', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000222', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000223', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 2) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- STATION 20: Ga Ha Noi (Hanoi Railway Station)
-- =============================================================================
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000023', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status, created_by, created_at, published_at)
VALUES (
    'f2000000-0000-0000-0000-000000000023',
    'f1000000-0000-0000-0000-000000000023',
    1, 'PUBLISHED',
    'VoltGo Battery Swap - Ga Hà Nội',
    'Ga Hà Nội, Quận Hoàn Kiếm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.84117, 21.02452), 4326),
    '05:00-23:00', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000023', 'f2000000-0000-0000-0000-000000000023', 'BATTERY_SWAP', 24, 45.0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000023', 24, 20, 45.0, NOW())
ON CONFLICT (station_id) DO NOTHING;

INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000230', 'f1000000-0000-0000-0000-000000000023', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000231', 'f1000000-0000-0000-0000-000000000023', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000232', 'f1000000-0000-0000-0000-000000000023', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000233', 'f1000000-0000-0000-0000-000000000023', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000230', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000231', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000232', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000233', s, 100, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s ON CONFLICT DO NOTHING;

-- =============================================================================
-- Sync available_batteries in battery_swap_station_state
-- =============================================================================
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

-- =============================================================================
-- Seed trust scores for all 20 stations
-- =============================================================================
INSERT INTO battery_swap_trust (id, station_id, score, breakdown, last_event_at, created_at, updated_at)
VALUES
    ('b1000000-0000-0000-0000-000000000010', 'f1000000-0000-0000-0000-000000000010', 92, '{"swapSuccessRate": 98, "uptimeScore": 95, "userRating": 4.6, "responseTimeScore": 90}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000011', 88, '{"swapSuccessRate": 95, "uptimeScore": 92, "userRating": 4.4, "responseTimeScore": 86}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000012', 90, '{"swapSuccessRate": 97, "uptimeScore": 93, "userRating": 4.5, "responseTimeScore": 88}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000013', 87, '{"swapSuccessRate": 94, "uptimeScore": 91, "userRating": 4.3, "responseTimeScore": 85}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000014', 'f1000000-0000-0000-0000-000000000014', 85, '{"swapSuccessRate": 93, "uptimeScore": 90, "userRating": 4.2, "responseTimeScore": 82}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000015', 'f1000000-0000-0000-0000-000000000015', 83, '{"swapSuccessRate": 91, "uptimeScore": 88, "userRating": 4.1, "responseTimeScore": 80}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000016', 'f1000000-0000-0000-0000-000000000016', 86, '{"swapSuccessRate": 93, "uptimeScore": 90, "userRating": 4.3, "responseTimeScore": 84}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000017', 'f1000000-0000-0000-0000-000000000017', 82, '{"swapSuccessRate": 90, "uptimeScore": 87, "userRating": 4.0, "responseTimeScore": 79}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000018', 'f1000000-0000-0000-0000-000000000018', 84, '{"swapSuccessRate": 92, "uptimeScore": 89, "userRating": 4.1, "responseTimeScore": 81}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000019', 'f1000000-0000-0000-0000-000000000019', 94, '{"swapSuccessRate": 99, "uptimeScore": 96, "userRating": 4.7, "responseTimeScore": 92}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-00000000001a', 'f1000000-0000-0000-0000-00000000001a', 89, '{"swapSuccessRate": 96, "uptimeScore": 93, "userRating": 4.4, "responseTimeScore": 87}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-00000000001b', 'f1000000-0000-0000-0000-00000000001b', 84, '{"swapSuccessRate": 92, "uptimeScore": 89, "userRating": 4.1, "responseTimeScore": 81}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-00000000001c', 'f1000000-0000-0000-0000-00000000001c', 86, '{"swapSuccessRate": 93, "uptimeScore": 90, "userRating": 4.3, "responseTimeScore": 84}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-00000000001d', 'f1000000-0000-0000-0000-00000000001d', 80, '{"swapSuccessRate": 88, "uptimeScore": 85, "userRating": 3.9, "responseTimeScore": 77}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-00000000001e', 'f1000000-0000-0000-0000-00000000001e', 85, '{"swapSuccessRate": 93, "uptimeScore": 90, "userRating": 4.2, "responseTimeScore": 82}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-00000000001f', 'f1000000-0000-0000-0000-00000000001f', 88, '{"swapSuccessRate": 95, "uptimeScore": 92, "userRating": 4.4, "responseTimeScore": 86}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000020', 'f1000000-0000-0000-0000-000000000020', 95, '{"swapSuccessRate": 99, "uptimeScore": 97, "userRating": 4.8, "responseTimeScore": 93}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000021', 'f1000000-0000-0000-0000-000000000021', 91, '{"swapSuccessRate": 97, "uptimeScore": 94, "userRating": 4.5, "responseTimeScore": 89}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000022', 'f1000000-0000-0000-0000-000000000022', 90, '{"swapSuccessRate": 96, "uptimeScore": 93, "userRating": 4.5, "responseTimeScore": 88}'::jsonb, NOW(), NOW(), NOW()),
    ('b1000000-0000-0000-0000-000000000023', 'f1000000-0000-0000-0000-000000000023', 93, '{"swapSuccessRate": 98, "uptimeScore": 95, "userRating": 4.6, "responseTimeScore": 91}'::jsonb, NOW(), NOW(), NOW())
ON CONFLICT (station_id) DO NOTHING;
