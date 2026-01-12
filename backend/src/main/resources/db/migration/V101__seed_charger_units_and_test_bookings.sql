-- Seed charger_units from charging_ports for published stations
-- Also seed test bookings for testing availability and double-booking scenarios

-- ============================================
-- 1. GENERATE CHARGER_UNITS FROM CHARGING_PORTS
-- ============================================

-- For each published station_version, expand charging_ports into charger_units
-- Strategy: For each charging_port with port_count > 0, create port_count units

INSERT INTO charger_unit (id, station_id, station_version_id, power_type, power_kw, label, price_per_hour, status, created_at)
SELECT 
    gen_random_uuid() as id,
    sv.station_id,
    sv.id as station_version_id,
    cp.power_type,
    cp.power_kw,
    CASE 
        WHEN cp.power_type = 'DC' THEN 
            'DC' || COALESCE(ROUND(cp.power_kw)::text, '') || '-' || LPAD(unit_num::text, 2, '0')
        ELSE 
            'AC-' || LPAD(unit_num::text, 2, '0')
    END as label,
    CASE 
        WHEN cp.power_type = 'DC' AND cp.power_kw >= 200 THEN 60000  -- 250kW DC: 60k VND/h
        WHEN cp.power_type = 'DC' AND cp.power_kw >= 100 THEN 40000  -- 120kW DC: 40k VND/h
        WHEN cp.power_type = 'DC' THEN 30000                          -- Other DC: 30k VND/h
        ELSE 20000                                                    -- AC: 20k VND/h
    END as price_per_hour,
    'ACTIVE'::charger_unit_status as status,
    NOW() as created_at
FROM station_version sv
JOIN station_service ss ON ss.station_version_id = sv.id
JOIN charging_port cp ON cp.station_service_id = ss.id
CROSS JOIN LATERAL generate_series(1, cp.port_count) as unit_num
WHERE sv.workflow_status = 'PUBLISHED'
ON CONFLICT (station_id, label) DO NOTHING;

-- ============================================
-- 2. CREATE TEST EV_USERS FOR BOOKING TESTS
-- ============================================

INSERT INTO user_account (id, email, password_hash, role, status, created_at)
VALUES 
    ('30000000-0000-0000-0000-000000000001', 'evuser1@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'EV_USER', 'ACTIVE', NOW()),
    ('30000000-0000-0000-0000-000000000002', 'evuser2@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'EV_USER', 'ACTIVE', NOW())
ON CONFLICT (email) DO NOTHING;

-- ============================================
-- 3. GET CHARGER_UNIT IDs FOR TEST BOOKINGS
-- ============================================

-- We'll use a subquery to get charger_unit IDs
-- For station a0000000-0000-0000-0000-000000000001 (Hoàn Kiếm)
-- Assuming it has DC250 units (DC250-01, DC250-02, etc.)

-- ============================================
-- 4. CREATE TEST BOOKINGS
-- ============================================

-- Booking 1: CONFIRMED booking for DC250-01 at tomorrow 10:00-11:00
INSERT INTO booking (id, user_id, station_id, charger_unit_id, start_time, end_time, status, hold_expires_at, price_snapshot, created_at)
SELECT 
    gen_random_uuid(),
    '30000000-0000-0000-0000-000000000001'::uuid,
    'a0000000-0000-0000-0000-000000000001'::uuid,
    cu.id,
    (CURRENT_DATE + INTERVAL '1 day' + TIME '10:00:00')::timestamptz,
    (CURRENT_DATE + INTERVAL '1 day' + TIME '11:00:00')::timestamptz,
    'CONFIRMED'::booking_status,
    NOW() - INTERVAL '1 hour', -- Already expired (not used for CONFIRMED)
    jsonb_build_object(
        'unitLabel', cu.label,
        'powerType', cu.power_type::text,
        'powerKw', cu.power_kw,
        'pricePerHour', cu.price_per_hour,
        'durationMinutes', 60,
        'amount', cu.price_per_hour
    ),
    NOW() - INTERVAL '2 hours'
FROM charger_unit cu
WHERE cu.station_id = 'a0000000-0000-0000-0000-000000000001'::uuid
  AND cu.label LIKE 'DC%'
  AND cu.status = 'ACTIVE'
ORDER BY cu.label
LIMIT 1
ON CONFLICT DO NOTHING;

-- Booking 2: HOLD booking (not expired) for DC250-02 at tomorrow 10:30-11:30 (overlaps with Booking 1 on different unit)
INSERT INTO booking (id, user_id, station_id, charger_unit_id, start_time, end_time, status, hold_expires_at, price_snapshot, created_at)
SELECT 
    gen_random_uuid(),
    '30000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000001'::uuid,
    cu.id,
    (CURRENT_DATE + INTERVAL '1 day' + TIME '10:30:00')::timestamptz,
    (CURRENT_DATE + INTERVAL '1 day' + TIME '11:30:00')::timestamptz,
    'HOLD'::booking_status,
    NOW() + INTERVAL '5 minutes', -- Will expire in 5 minutes
    jsonb_build_object(
        'unitLabel', cu.label,
        'powerType', cu.power_type::text,
        'powerKw', cu.power_kw,
        'pricePerHour', cu.price_per_hour,
        'durationMinutes', 60,
        'amount', cu.price_per_hour
    ),
    NOW() - INTERVAL '5 minutes'
FROM charger_unit cu
WHERE cu.station_id = 'a0000000-0000-0000-0000-000000000001'::uuid
  AND cu.label LIKE 'DC%'
  AND cu.status = 'ACTIVE'
  AND cu.id NOT IN (
      SELECT charger_unit_id FROM booking 
      WHERE status IN ('HOLD', 'CONFIRMED')
      LIMIT 1
  )
ORDER BY cu.label
LIMIT 1
ON CONFLICT DO NOTHING;

-- Booking 3: EXPIRED HOLD (will be expired by scheduler) for DC250-03
INSERT INTO booking (id, user_id, station_id, charger_unit_id, start_time, end_time, status, hold_expires_at, price_snapshot, created_at)
SELECT 
    gen_random_uuid(),
    '30000000-0000-0000-0000-000000000001'::uuid,
    'a0000000-0000-0000-0000-000000000001'::uuid,
    cu.id,
    (CURRENT_DATE + INTERVAL '2 days' + TIME '14:00:00')::timestamptz,
    (CURRENT_DATE + INTERVAL '2 days' + TIME '15:00:00')::timestamptz,
    'HOLD'::booking_status,
    NOW() - INTERVAL '1 hour', -- Already expired
    jsonb_build_object(
        'unitLabel', cu.label,
        'powerType', cu.power_type::text,
        'powerKw', cu.power_kw,
        'pricePerHour', cu.price_per_hour,
        'durationMinutes', 60,
        'amount', cu.price_per_hour
    ),
    NOW() - INTERVAL '2 hours'
FROM charger_unit cu
WHERE cu.station_id = 'a0000000-0000-0000-0000-000000000001'::uuid
  AND cu.label LIKE 'DC%'
  AND cu.status = 'ACTIVE'
  AND cu.id NOT IN (
      SELECT charger_unit_id FROM booking 
      WHERE status IN ('HOLD', 'CONFIRMED')
      LIMIT 2
  )
ORDER BY cu.label
LIMIT 1
ON CONFLICT DO NOTHING;

-- Booking 4: CANCELLED booking (doesn't block) for DC250-04
INSERT INTO booking (id, user_id, station_id, charger_unit_id, start_time, end_time, status, hold_expires_at, price_snapshot, created_at)
SELECT 
    gen_random_uuid(),
    '30000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000001'::uuid,
    cu.id,
    (CURRENT_DATE + INTERVAL '3 days' + TIME '16:00:00')::timestamptz,
    (CURRENT_DATE + INTERVAL '3 days' + TIME '17:00:00')::timestamptz,
    'CANCELLED'::booking_status,
    NOW() - INTERVAL '1 day',
    jsonb_build_object(
        'unitLabel', cu.label,
        'powerType', cu.power_type::text,
        'powerKw', cu.power_kw,
        'pricePerHour', cu.price_per_hour,
        'durationMinutes', 60,
        'amount', cu.price_per_hour
    ),
    NOW() - INTERVAL '2 days'
FROM charger_unit cu
WHERE cu.station_id = 'a0000000-0000-0000-0000-000000000001'::uuid
  AND cu.label LIKE 'DC%'
  AND cu.status = 'ACTIVE'
ORDER BY cu.label
LIMIT 1
ON CONFLICT DO NOTHING;

-- Note: The exclusion constraint will prevent double-booking, so these test bookings
-- are designed to test different scenarios without conflicts.

