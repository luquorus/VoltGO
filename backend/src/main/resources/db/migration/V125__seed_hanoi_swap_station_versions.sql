-- V125: Add battery_swap_station_version + pile_template + slot_template for 20 Hanoi stations
-- These tables are required for the admin listStations() endpoint to show stations.

-- =============================================================================
-- Station 1: Hoan Kiem (4 piles x 6 slots)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000010', 'f1000000-0000-0000-0000-000000000010', 1, 'PUBLISHED', 24, 40.0, '06:00-22:00', 0.00, 'VoltGo Battery Swap - Hoan Kiem Lake, 24/7 operation', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000010', 'g1000000-0000-0000-0000-000000000010', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000010', 'g1000000-0000-0000-0000-000000000010', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000010', 'g1000000-0000-0000-0000-000000000010', 3, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-000000000010', 'g1000000-0000-0000-0000-000000000010', 4, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 2: Den Ngoc Son (3 piles x 6,6,4)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000011', 1, 'PUBLISHED', 16, 35.0, '07:00-21:00', 5000.00, 'VoltGo Battery Swap - Den Ngoc Son', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000011', 'g1000000-0000-0000-0000-000000000011', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000011', 'g1000000-0000-0000-0000-000000000011', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000011', 'g1000000-0000-0000-0000-000000000011', 3, 4) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 3: Nha Hat Lon (4 piles x 6,6,5,3)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000012', 1, 'PUBLISHED', 20, 38.0, '06:00-23:00', 10000.00, 'VoltGo Battery Swap - Nha Hat Lon Hanoi', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000012', 'g1000000-0000-0000-0000-000000000012', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000012', 'g1000000-0000-0000-0000-000000000012', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000012', 'g1000000-0000-0000-0000-000000000012', 3, 5) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-000000000012', 'g1000000-0000-0000-0000-000000000012', 4, 3) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 4: Van Mieu (3 piles x 6,6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000013', 1, 'PUBLISHED', 18, 35.0, '07:00-18:00', 20000.00, 'VoltGo Battery Swap - Van Mieu Quoc Tu Giam', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000013', 'g1000000-0000-0000-0000-000000000013', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000013', 'g1000000-0000-0000-0000-000000000013', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000013', 'g1000000-0000-0000-0000-000000000013', 3, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 5: Lang Chu Tich HCM (2 piles x 6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000014', 'f1000000-0000-0000-0000-000000000014', 1, 'PUBLISHED', 12, 38.0, '08:00-17:00', 0.00, 'VoltGo Battery Swap - Lang Chu Tich Ho Chi Minh', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000014', 'g1000000-0000-0000-0000-000000000014', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000014', 'g1000000-0000-0000-0000-000000000014', 2, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 6: Chua Mot Cot (2 piles x 6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000015', 'f1000000-0000-0000-0000-000000000015', 1, 'PUBLISHED', 12, 35.0, '07:00-18:00', 0.00, 'VoltGo Battery Swap - Chua Mot Cot', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000015', 'g1000000-0000-0000-0000-000000000015', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000015', 'g1000000-0000-0000-0000-000000000015', 2, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 7: Hoang Thanh Thang Long (3 piles x 6,6,4)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000016', 'f1000000-0000-0000-0000-000000000016', 1, 'PUBLISHED', 16, 38.0, '08:00-17:00', 0.00, 'VoltGo Battery Swap - Hoang Thanh Thang Long', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000016', 'g1000000-0000-0000-0000-000000000016', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000016', 'g1000000-0000-0000-0000-000000000016', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000016', 'g1000000-0000-0000-0000-000000000016', 3, 4) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 8: Cot Co Ha Noi (2 piles x 6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000017', 'f1000000-0000-0000-0000-000000000017', 1, 'PUBLISHED', 12, 35.0, '07:00-17:00', 0.00, 'VoltGo Battery Swap - Cot Co Ha Noi', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000017', 'g1000000-0000-0000-0000-000000000017', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000017', 'g1000000-0000-0000-0000-000000000017', 2, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 9: Nha Tu Hoa Lo (3 piles x 6,6,4)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000018', 'f1000000-0000-0000-0000-000000000018', 1, 'PUBLISHED', 16, 35.0, '08:00-17:30', 15000.00, 'VoltGo Battery Swap - Nha Tu Hoa Lo', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000018', 'g1000000-0000-0000-0000-000000000018', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000018', 'g1000000-0000-0000-0000-000000000018', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000018', 'g1000000-0000-0000-0000-000000000018', 3, 4) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 10: Ho Tay (4 piles x 6,6,6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000019', 'f1000000-0000-0000-0000-000000000019', 1, 'PUBLISHED', 24, 42.0, '24/7', 10000.00, 'VoltGo Battery Swap - Ho Tay, Tay Ho District', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000019', 'g1000000-0000-0000-0000-000000000019', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000019', 'g1000000-0000-0000-0000-000000000019', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000019', 'g1000000-0000-0000-0000-000000000019', 3, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-000000000019', 'g1000000-0000-0000-0000-000000000019', 4, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 11: Chua Tran Quoc (3 piles x 6,6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-00000000001a', 'f1000000-0000-0000-0000-00000000001a', 1, 'PUBLISHED', 18, 38.0, '06:00-21:00', 0.00, 'VoltGo Battery Swap - Chua Tran Quoc', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-00000000001a', 'g1000000-0000-0000-0000-00000000001a', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-00000000001a', 'g1000000-0000-0000-0000-00000000001a', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-00000000001a', 'g1000000-0000-0000-0000-00000000001a', 3, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 12: Den Quan Thanh (3 piles x 6,6,4)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-00000000001b', 'f1000000-0000-0000-0000-00000000001b', 1, 'PUBLISHED', 16, 35.0, '07:00-18:00', 0.00, 'VoltGo Battery Swap - Den Quan Thanh', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-00000000001b', 'g1000000-0000-0000-0000-00000000001b', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-00000000001b', 'g1000000-0000-0000-0000-00000000001b', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-00000000001b', 'g1000000-0000-0000-0000-00000000001b', 3, 4) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 13: Cau Long Bien (4 piles x 6,6,5,3)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-00000000001c', 'f1000000-0000-0000-0000-00000000001c', 1, 'PUBLISHED', 20, 38.0, '24/7', 0.00, 'VoltGo Battery Swap - Cau Long Bien', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-00000000001c', 'g1000000-0000-0000-0000-00000000001c', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-00000000001c', 'g1000000-0000-0000-0000-00000000001c', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-00000000001c', 'g1000000-0000-0000-0000-00000000001c', 3, 5) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-00000000001c', 'g1000000-0000-0000-0000-00000000001c', 4, 3) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 14: Bao Tang Dan Toc (3 piles x 6,5,5)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-00000000001d', 'f1000000-0000-0000-0000-00000000001d', 1, 'PUBLISHED', 16, 35.0, '08:30-17:30', 30000.00, 'VoltGo Battery Swap - Bao Tang Dan Toc Hoc Viet Nam', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-00000000001d', 'g1000000-0000-0000-0000-00000000001d', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-00000000001d', 'g1000000-0000-0000-0000-00000000001d', 2, 5) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-00000000001d', 'g1000000-0000-0000-0000-00000000001d', 3, 5) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 15: Bao Tang HCM (3 piles x 6,6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-00000000001e', 'f1000000-0000-0000-0000-00000000001e', 1, 'PUBLISHED', 18, 38.0, '08:00-17:00', 0.00, 'VoltGo Battery Swap - Bao Tang Ho Chi Minh', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-00000000001e', 'g1000000-0000-0000-0000-00000000001e', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-00000000001e', 'g1000000-0000-0000-0000-00000000001e', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-00000000001e', 'g1000000-0000-0000-0000-00000000001e', 3, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 16: Cong Vien Thong Nhat (4 piles x 6,6,5,3)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-00000000001f', 'f1000000-0000-0000-0000-00000000001f', 1, 'PUBLISHED', 20, 38.0, '06:00-22:00', 0.00, 'VoltGo Battery Swap - Cong Vien Thong Nhat', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-00000000001f', 'g1000000-0000-0000-0000-00000000001f', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-00000000001f', 'g1000000-0000-0000-0000-00000000001f', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-00000000001f', 'g1000000-0000-0000-0000-00000000001f', 3, 5) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-00000000001f', 'g1000000-0000-0000-0000-00000000001f', 4, 3) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 17: Keangnam Landmark 72 (4 piles x 6,6,6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000020', 'f1000000-0000-0000-0000-000000000020', 1, 'PUBLISHED', 24, 45.0, '24/7', 20000.00, 'VoltGo Battery Swap - Keangnam Landmark 72, Nam Tu Liem', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000020', 'g1000000-0000-0000-0000-000000000020', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000020', 'g1000000-0000-0000-0000-000000000020', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000020', 'g1000000-0000-0000-0000-000000000020', 3, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-000000000020', 'g1000000-0000-0000-0000-000000000020', 4, 6) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 18: Lotte Observation Deck (4 piles x 6,6,5,3)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000021', 'f1000000-0000-0000-0000-000000000021', 1, 'PUBLISHED', 20, 42.0, '09:00-22:00', 15000.00, 'VoltGo Battery Swap - Lotte Center Observation Deck', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000021', 'g1000000-0000-0000-0000-000000000021', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000021', 'g1000000-0000-0000-0000-000000000021', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000021', 'g1000000-0000-0000-0000-000000000021', 3, 5) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-000000000021', 'g1000000-0000-0000-0000-000000000021', 4, 3) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 19: Vincom Center Ba Trieu (4 piles x 6,6,5,3)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000022', 'f1000000-0000-0000-0000-000000000022', 1, 'PUBLISHED', 20, 40.0, '10:00-22:00', 20000.00, 'VoltGo Battery Swap - Vincom Center Ba Trieu', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000022', 'g1000000-0000-0000-0000-000000000022', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000022', 'g1000000-0000-0000-0000-000000000022', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000022', 'g1000000-0000-0000-0000-000000000022', 3, 5) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-000000000022', 'g1000000-0000-0000-0000-000000000022', 4, 3) ON CONFLICT DO NOTHING;

-- =============================================================================
-- Station 20: Ga Ha Noi (4 piles x 6,6,6,6)
-- =============================================================================
INSERT INTO battery_swap_station_version (id, station_id, version_no, workflow_status, total_batteries, avg_charge_power_kw, operating_hours, parking_fee, note, created_by, created_at, published_at, submitted_at)
VALUES ('g1000000-0000-0000-0000-000000000023', 'f1000000-0000-0000-0000-000000000023', 1, 'PUBLISHED', 24, 45.0, '05:00-23:00', 10000.00, 'VoltGo Battery Swap - Ga Ha Noi, Hoan Kiem District', '00000000-0000-0000-0000-000000000001', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1100000-0000-0000-0000-000000000023', 'g1000000-0000-0000-0000-000000000023', 1, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1200000-0000-0000-0000-000000000023', 'g1000000-0000-0000-0000-000000000023', 2, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1300000-0000-0000-0000-000000000023', 'g1000000-0000-0000-0000-000000000023', 3, 6) ON CONFLICT DO NOTHING;
INSERT INTO battery_swap_pile_template (id, station_version_id, pile_index, slots_per_pile) VALUES ('h1400000-0000-0000-0000-000000000023', 'g1000000-0000-0000-0000-000000000023', 4, 6) ON CONFLICT DO NOTHING;
