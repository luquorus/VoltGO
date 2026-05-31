-- Manual seed for battery-swap demo stations (same as Flyway V111).
-- Run from repo root:
--   Get-Content infra/seed_battery_swap_samples.sql | docker exec -i voltgo-postgres psql -U voltgo_user -d voltgo

-- Station 1: Hoan Kiem
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'f2000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 1, 'PUBLISHED',
    'Battery Swap Hoan Kiem Demo', '12 Hang Bai, Hoan Kiem, Hanoi',
    ST_SetSRID(ST_MakePoint(105.8545, 21.0288), 4326), '24/7', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000001', 'f2000000-0000-0000-0000-000000000001', 'BATTERY_SWAP', 24, 40.0)
ON CONFLICT (id) DO UPDATE SET total_batteries = EXCLUDED.total_batteries, avg_charge_power_kw = EXCLUDED.avg_charge_power_kw;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000001', 24, 12, 40.0, NOW())
ON CONFLICT (station_id) DO UPDATE SET total_batteries = 24, available_batteries = 12, avg_charge_power_kw = 40.0, updated_at = NOW();

-- Station 2: Ba Dinh
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'f2000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002', 1, 'PUBLISHED',
    'Battery Swap Ba Dinh Demo', '2 Lieu Giai, Ba Dinh, Hanoi',
    ST_SetSRID(ST_MakePoint(105.8120, 21.0355), 4326), '06:00-22:00', 'PAID', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000002', 'f2000000-0000-0000-0000-000000000002', 'BATTERY_SWAP', 16, 35.0)
ON CONFLICT (id) DO UPDATE SET total_batteries = EXCLUDED.total_batteries, avg_charge_power_kw = EXCLUDED.avg_charge_power_kw;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000002', 16, 8, 35.0, NOW())
ON CONFLICT (station_id) DO UPDATE SET total_batteries = 16, available_batteries = 8, avg_charge_power_kw = 35.0, updated_at = NOW();

-- Station 3: Cau Giay
INSERT INTO station (id, provider_id, created_at)
VALUES ('f1000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'f2000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000003', 1, 'PUBLISHED',
    'Battery Swap Cau Giay Demo', '100 Xuan Thuy, Cau Giay, Hanoi',
    ST_SetSRID(ST_MakePoint(105.7850, 21.0380), 4326), '24/7', 'FREE', 'PUBLIC', 'ACTIVE',
    '20000000-0000-0000-0000-000000000001', NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_service (id, station_version_id, service_type, total_batteries, avg_charge_power_kw)
VALUES ('f3000000-0000-0000-0000-000000000003', 'f2000000-0000-0000-0000-000000000003', 'BATTERY_SWAP', 20, 35.0)
ON CONFLICT (id) DO UPDATE SET total_batteries = EXCLUDED.total_batteries, avg_charge_power_kw = EXCLUDED.avg_charge_power_kw;

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at)
VALUES ('f1000000-0000-0000-0000-000000000003', 20, 15, 35.0, NOW())
ON CONFLICT (station_id) DO UPDATE SET total_batteries = 20, available_batteries = 15, avg_charge_power_kw = 35.0, updated_at = NOW();
