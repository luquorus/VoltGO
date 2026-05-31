-- Station 1: 4 piles (24 batteries = 4 piles x 6 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000001', s.slot_idx, 90 + floor(random() * 11)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000002', s.slot_idx, 90 + floor(random() * 11)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000003', s.slot_idx, 85 + floor(random() * 16)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000004', s.slot_idx, 80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Station 2: 3 piles (16 batteries = 6+6+4 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000011', 'f1000000-0000-0000-0000-000000000002', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000012', 'f1000000-0000-0000-0000-000000000002', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000013', 'f1000000-0000-0000-0000-000000000002', 3, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000011', s.slot_idx, 70 + floor(random() * 31)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000012', s.slot_idx, 70 + floor(random() * 31)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000013', s.slot_idx, 70 + floor(random() * 31)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 3) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- Station 3: 4 piles (20 batteries = 5+5+5+5 slots)
INSERT INTO swap_pile (id, station_id, pile_index, status, created_at, updated_at)
VALUES
    ('e1000000-0000-0000-0000-000000000021', 'f1000000-0000-0000-0000-000000000003', 1, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000022', 'f1000000-0000-0000-0000-000000000003', 2, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000023', 'f1000000-0000-0000-0000-000000000003', 3, 'ACTIVE', NOW(), NOW()),
    ('e1000000-0000-0000-0000-000000000024', 'f1000000-0000-0000-0000-000000000003', 4, 'ACTIVE', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000021', s.slot_idx, 80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000022', s.slot_idx, 80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000023', s.slot_idx, 80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000024', s.slot_idx, 80 + floor(random() * 21)::int, 'AVAILABLE', NOW()
FROM generate_series(0, 4) AS s(slot_idx)
ON CONFLICT DO NOTHING;
