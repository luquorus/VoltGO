-- V119: Fix V114 seed data và thêm index còn thiếu
--
-- Phần 1: V114 — slotIndex trong seed dùng generate_series(0, n) tạo index 0-based
--   nhưng Entity dùng slotIndex 1-based. Sửa tất cả seed để slotIndex bắt đầu từ 1.
--
-- Phần 2: V114 — Station 3, Pile 4 có 5 slots nhưng logic tạo 4 piles × 5 slots
--   (20 total) khớp với V111. Tuy nhiên seed hiện tại tạo 23 slots.
--   Sửa lại: Pile 4 chỉ có 4 slots (slot_idx 1..4), tổng = 4+4+4+4 = 16 slots cho Station 3.
--   Cập nhật battery_swap_station_state.available_batteries sau khi fix.
--
-- Phần 3: V109 — bảng battery_swap_station_state thiếu index trên updated_at.
--   Cần index để query "trạm nào vừa được cập nhật" hiệu quả.

-- =====================================================================
-- 1. Sửa slotIndex trong seed: bắt đầu từ 1 (không phải 0)
-- =====================================================================

-- Station 1: 4 piles × 5 slots = 20 total (thay vì 4×6=24)
-- Xóa slots cũ của Station 1 (pile e1000000-0000-0000-0000-000000000001 ~ 004)
DELETE FROM battery_slot
WHERE pile_id IN (
    'e1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003',
    'e1000000-0000-0000-0000-000000000004'
);

-- Tạo lại Station 1: 4 piles × 5 slots (slotIndex 1..5)
INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000001',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000002',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000003',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT
    gen_random_uuid(),
    'e1000000-0000-0000-0000-000000000004',
    s.slot_idx,
    100,
    'AVAILABLE',
    NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 2. Sửa Station 2: 3 piles (5+5+5 = 15 slots) thay vì 6+6+4 = 16
-- =====================================================================

DELETE FROM battery_slot
WHERE pile_id IN (
    'e1000000-0000-0000-0000-000000000011',
    'e1000000-0000-0000-0000-000000000012',
    'e1000000-0000-0000-0000-000000000013'
);

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000011', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000012', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000013', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 3. Sửa Station 3: 4 piles × 5 slots = 20 slots (slotIndex 1..5)
-- =====================================================================

DELETE FROM battery_slot
WHERE pile_id IN (
    'e1000000-0000-0000-0000-000000000021',
    'e1000000-0000-0000-0000-000000000022',
    'e1000000-0000-0000-0000-000000000023',
    'e1000000-0000-0000-0000-000000000024'
);

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000021', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000022', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000023', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

INSERT INTO battery_slot (id, pile_id, slot_index, battery_charge_percent, status, updated_at)
SELECT gen_random_uuid(), 'e1000000-0000-0000-0000-000000000024', s.slot_idx,
       100, 'AVAILABLE', NOW()
FROM generate_series(1, 5) AS s(slot_idx)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 4. Cập nhật available_batteries sau khi fix slot count
-- =====================================================================

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

-- =====================================================================
-- 5. Thêm index cho battery_swap_station_state.updated_at (V109 thiếu)
-- =====================================================================

CREATE INDEX IF NOT EXISTS idx_battery_swap_station_state_updated_at
    ON battery_swap_station_state(updated_at DESC);
