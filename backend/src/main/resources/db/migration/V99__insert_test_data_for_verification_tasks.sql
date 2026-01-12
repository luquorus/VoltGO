-- Test Data for Admin Verification Tasks UI Testing
-- Run this script after all migrations to populate test data

-- Note: Using fixed UUIDs for easier testing
-- Password hash for "Admin@123" (BCrypt)
-- You can generate new hash using: BCryptPasswordEncoder.encode("Admin@123")

-- ============================================
-- 1. USERS
-- ============================================

-- Admin user (already created by DataInitializer, but ensure it exists)
INSERT INTO user_account (id, email, password_hash, role, status, created_at)
VALUES 
    ('00000000-0000-0000-0000-000000000001', 'admin@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'ADMIN', 'ACTIVE', NOW())
ON CONFLICT (email) DO NOTHING;

-- Collaborator users (for assigning tasks)
INSERT INTO user_account (id, email, password_hash, role, status, created_at)
VALUES 
    ('10000000-0000-0000-0000-000000000001', 'collab1@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'COLLABORATOR', 'ACTIVE', NOW()),
    ('10000000-0000-0000-0000-000000000002', 'collab2@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'COLLABORATOR', 'ACTIVE', NOW())
ON CONFLICT (email) DO NOTHING;

-- Provider user (for creating stations)
INSERT INTO user_account (id, email, password_hash, role, status, created_at)
VALUES 
    ('20000000-0000-0000-0000-000000000001', 'provider1@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'PROVIDER', 'ACTIVE', NOW())
ON CONFLICT (email) DO NOTHING;

-- ============================================
-- 2. STATIONS (with published versions for stationName)
-- ============================================

-- Station 1: Hanoi - Hoàn Kiếm District
INSERT INTO station (id, provider_id, created_at)
VALUES 
    ('a0000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address, 
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    1,
    'PUBLISHED',
    'EV Station Hoàn Kiếm',
    '36 Tràng Tiền, Hoàn Kiếm, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.8542, 21.0285), 4326), -- Coordinates for Hoàn Kiếm, Hanoi
    '24/7',
    'FREE',
    'PUBLIC',
    'ACTIVE',
    '20000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '30 days',
    NOW() - INTERVAL '25 days'
)
ON CONFLICT (id) DO NOTHING;

-- Station 2: Hanoi - Ba Đình District
INSERT INTO station (id, provider_id, created_at)
VALUES 
    ('a0000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000002',
    1,
    'PUBLISHED',
    'EV Station Ba Đình',
    '12 Hoàng Diệu, Ba Đình, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.8170, 21.0340), 4326), -- Coordinates for Ba Đình, Hanoi
    '6:00 - 22:00',
    'PAID',
    'PUBLIC',
    'ACTIVE',
    '20000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '20 days',
    NOW() - INTERVAL '15 days'
)
ON CONFLICT (id) DO NOTHING;

-- Station 3: Hanoi - Cầu Giấy District
INSERT INTO station (id, provider_id, created_at)
VALUES 
    ('a0000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000003',
    1,
    'PUBLISHED',
    'EV Station Cầu Giấy',
    '168 Xuân Thủy, Cầu Giấy, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.7900, 21.0380), 4326), -- Coordinates for Cầu Giấy, Hanoi
    '24/7',
    'FREE',
    'PUBLIC',
    'ACTIVE',
    '20000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '10 days',
    NOW() - INTERVAL '5 days'
)
ON CONFLICT (id) DO NOTHING;

-- Station 4: Hanoi - Tây Hồ District
INSERT INTO station (id, provider_id, created_at)
VALUES 
    ('a0000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO station_version (
    id, station_id, version_no, workflow_status, name, address,
    location, operating_hours, parking, visibility, public_status,
    created_by, created_at, published_at
)
VALUES (
    'b0000000-0000-0000-0000-000000000004',
    'a0000000-0000-0000-0000-000000000004',
    1,
    'PUBLISHED',
    'EV Station Tây Hồ',
    '58 Quảng An, Tây Hồ, Hà Nội',
    ST_SetSRID(ST_MakePoint(105.8230, 21.0680), 4326), -- Coordinates for Tây Hồ, Hanoi
    '6:00 - 23:00',
    'FREE',
    'PUBLIC',
    'ACTIVE',
    '20000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '15 days',
    NOW() - INTERVAL '10 days'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 3. CHANGE REQUESTS (for linking to tasks)
-- ============================================

-- Change Request 1: PENDING
INSERT INTO change_request (
    id, type, status, station_id, proposed_station_version_id,
    submitted_by, risk_score, risk_reasons, created_at, submitted_at
)
VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'UPDATE_STATION',
    'PENDING',
    'a0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    45,
    '["PORTS_CHANGED"]'::jsonb,
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '4 days'
)
ON CONFLICT (id) DO NOTHING;

-- Change Request 2: APPROVED
INSERT INTO change_request (
    id, type, status, station_id, proposed_station_version_id,
    submitted_by, risk_score, risk_reasons, created_at, submitted_at, decided_at
)
VALUES (
    'c0000000-0000-0000-0000-000000000002',
    'UPDATE_STATION',
    'APPROVED',
    'a0000000-0000-0000-0000-000000000002',
    'b0000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    25,
    '["HOURS_CHANGED"]'::jsonb,
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '1 day'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 4. VERIFICATION TASKS
-- ============================================

-- Task 1: OPEN (no checkin, no evidence, no review)
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    NULL,
    5,
    NOW() + INTERVAL '24 hours',
    NULL,
    'OPEN',
    NOW() - INTERVAL '2 days'
)
ON CONFLICT (id) DO NOTHING;

-- Task 2: OPEN (high priority, overdue SLA)
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    5,
    NOW() - INTERVAL '2 hours', -- Overdue
    NULL,
    'OPEN',
    NOW() - INTERVAL '3 days'
)
ON CONFLICT (id) DO NOTHING;

-- Task 3: ASSIGNED
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000003',
    NULL,
    3,
    NOW() + INTERVAL '48 hours',
    '10000000-0000-0000-0000-000000000001',
    'ASSIGNED',
    NOW() - INTERVAL '1 day'
)
ON CONFLICT (id) DO NOTHING;

-- Task 4: CHECKED_IN (with checkin data)
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000004',
    'a0000000-0000-0000-0000-000000000001',
    NULL,
    4,
    NOW() + INTERVAL '12 hours',
    '10000000-0000-0000-0000-000000000002',
    'CHECKED_IN',
    NOW() - INTERVAL '1 day'
)
ON CONFLICT (id) DO NOTHING;

-- Checkin for Task 4
INSERT INTO verification_checkin (
    id, task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
)
VALUES (
    'c0000000-0000-0000-0000-000000000004',
    'f0000000-0000-0000-0000-000000000004',
    21.0285,  -- Near Hoàn Kiếm station
    105.8542,
    NOW() - INTERVAL '6 hours',
    50, -- 50 meters from station
    'GPS accuracy: 10m, device: iPhone 15'
)
ON CONFLICT (id) DO NOTHING;

-- Task 5: SUBMITTED (with checkin + evidences, ready for review)
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000005',
    'a0000000-0000-0000-0000-000000000002',
    NULL,
    3,
    NOW() + INTERVAL '6 hours',
    '10000000-0000-0000-0000-000000000001',
    'SUBMITTED',
    NOW() - INTERVAL '3 days'
)
ON CONFLICT (id) DO NOTHING;

-- Checkin for Task 5
INSERT INTO verification_checkin (
    id, task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
)
VALUES (
    'c0000000-0000-0000-0000-000000000005',
    'f0000000-0000-0000-0000-000000000005',
    21.0340,  -- Near Ba Đình station
    105.8170,
    NOW() - INTERVAL '2 days',
    120, -- 120 meters from station
    'GPS accuracy: 15m, device: Samsung Galaxy S23'
)
ON CONFLICT (id) DO NOTHING;

-- Evidences for Task 5
INSERT INTO verification_evidence (
    id, task_id, photo_object_key, note, submitted_at, submitted_by
)
VALUES 
    (
        'e0000000-0000-0000-0000-000000000001',
        'f0000000-0000-0000-0000-000000000005',
        'evidence/2024/task-005/photo-1.jpg',
        'Front view of charging station',
        NOW() - INTERVAL '1 day',
        '10000000-0000-0000-0000-000000000001'
    ),
    (
        'e0000000-0000-0000-0000-000000000002',
        'f0000000-0000-0000-0000-000000000005',
        'evidence/2024/task-005/photo-2.jpg',
        'Side view showing charging ports',
        NOW() - INTERVAL '1 day',
        '10000000-0000-0000-0000-000000000001'
    ),
    (
        'e0000000-0000-0000-0000-000000000003',
        'f0000000-0000-0000-0000-000000000005',
        'evidence/2024/task-005/photo-3.jpg',
        NULL, -- No note
        NOW() - INTERVAL '23 hours',
        '10000000-0000-0000-0000-000000000001'
    )
ON CONFLICT (id) DO NOTHING;

-- Task 6: REVIEWED - PASS
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000006',
    'a0000000-0000-0000-0000-000000000003',
    NULL,
    2,
    NOW() - INTERVAL '1 day', -- Past due but reviewed
    '10000000-0000-0000-0000-000000000002',
    'REVIEWED',
    NOW() - INTERVAL '7 days'
)
ON CONFLICT (id) DO NOTHING;

-- Checkin for Task 6
INSERT INTO verification_checkin (
    id, task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
)
VALUES (
    'c0000000-0000-0000-0000-000000000006',
    'f0000000-0000-0000-0000-000000000006',
    21.0380,  -- Near Cầu Giấy station
    105.7900,
    NOW() - INTERVAL '5 days',
    80,
    'GPS accuracy: 8m'
)
ON CONFLICT (id) DO NOTHING;

-- Evidences for Task 6
INSERT INTO verification_evidence (
    id, task_id, photo_object_key, note, submitted_at, submitted_by
)
VALUES 
    (
        'e0000000-0000-0000-0000-000000000004',
        'f0000000-0000-0000-0000-000000000006',
        'evidence/2024/task-006/photo-1.jpg',
        'Station entrance',
        NOW() - INTERVAL '4 days',
        '10000000-0000-0000-0000-000000000002'
    ),
    (
        'e0000000-0000-0000-0000-000000000005',
        'f0000000-0000-0000-0000-000000000006',
        'evidence/2024/task-006/photo-2.jpg',
        'Charging ports working properly',
        NOW() - INTERVAL '4 days',
        '10000000-0000-0000-0000-000000000002'
    )
ON CONFLICT (id) DO NOTHING;

-- Review for Task 6 (PASS)
INSERT INTO verification_review (
    id, task_id, result, admin_note, reviewed_at, reviewed_by
)
VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'f0000000-0000-0000-0000-000000000006',
    'PASS',
    'Station verified successfully. All charging ports operational. Location accurate.',
    NOW() - INTERVAL '3 days',
    '00000000-0000-0000-0000-000000000001' -- Admin user
)
ON CONFLICT (id) DO NOTHING;

-- Task 7: REVIEWED - FAIL
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000007',
    'a0000000-0000-0000-0000-000000000004',
    'c0000000-0000-0000-0000-000000000002',
    4,
    NOW() - INTERVAL '3 days',
    '10000000-0000-0000-0000-000000000001',
    'REVIEWED',
    NOW() - INTERVAL '10 days'
)
ON CONFLICT (id) DO NOTHING;

-- Checkin for Task 7
INSERT INTO verification_checkin (
    id, task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
)
VALUES (
    'c0000000-0000-0000-0000-000000000007',
    'f0000000-0000-0000-0000-000000000007',
    21.0680,  -- Near Tây Hồ station
    105.8230,
    NOW() - INTERVAL '8 days',
    200, -- 200 meters - far from station
    'GPS accuracy: 20m'
)
ON CONFLICT (id) DO NOTHING;

-- Evidences for Task 7
INSERT INTO verification_evidence (
    id, task_id, photo_object_key, note, submitted_at, submitted_by
)
VALUES 
    (
        'e0000000-0000-0000-0000-000000000006',
        'f0000000-0000-0000-0000-000000000007',
        'evidence/2024/task-007/photo-1.jpg',
        'Station location mismatch - found at different address',
        NOW() - INTERVAL '7 days',
        '10000000-0000-0000-0000-000000000001'
    )
ON CONFLICT (id) DO NOTHING;

-- Review for Task 7 (FAIL)
INSERT INTO verification_review (
    id, task_id, result, admin_note, reviewed_at, reviewed_by
)
VALUES (
    'd0000000-0000-0000-0000-000000000002',
    'f0000000-0000-0000-0000-000000000007',
    'FAIL',
    'Location verification failed. Station not found at specified address. Requires re-verification.',
    NOW() - INTERVAL '6 days',
    '00000000-0000-0000-0000-000000000001' -- Admin user
)
ON CONFLICT (id) DO NOTHING;

-- Task 8: OPEN (low priority, no SLA)
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000008',
    'a0000000-0000-0000-0000-000000000001',
    NULL,
    1,
    NULL, -- No SLA
    NULL,
    'OPEN',
    NOW() - INTERVAL '5 hours'
)
ON CONFLICT (id) DO NOTHING;

-- Task 9: ASSIGNED (medium priority, with SLA)
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000009',
    'a0000000-0000-0000-0000-000000000002',
    NULL,
    3,
    NOW() + INTERVAL '72 hours',
    '10000000-0000-0000-0000-000000000002',
    'ASSIGNED',
    NOW() - INTERVAL '12 hours'
)
ON CONFLICT (id) DO NOTHING;

-- Task 10: CHECKED_IN (with checkin, no evidence yet)
INSERT INTO verification_task (
    id, station_id, change_request_id, priority, sla_due_at,
    assigned_to, status, created_at
)
VALUES (
    'f0000000-0000-0000-0000-000000000010',
    'a0000000-0000-0000-0000-000000000003',
    NULL,
    2,
    NOW() + INTERVAL '36 hours',
    '10000000-0000-0000-0000-000000000001',
    'CHECKED_IN',
    NOW() - INTERVAL '2 days'
)
ON CONFLICT (id) DO NOTHING;

-- Checkin for Task 10
INSERT INTO verification_checkin (
    id, task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
)
VALUES (
    'c0000000-0000-0000-0000-000000000010',
    'f0000000-0000-0000-0000-000000000010',
    21.0380,  -- Near Cầu Giấy station
    105.7900,
    NOW() - INTERVAL '1 hour',
    35,
    'On-site verification in progress'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 5. STATION SERVICES & CHARGING PORTS (for station data completeness)
-- ============================================

-- Services for Station 1
INSERT INTO station_service (id, station_version_id, service_type)
VALUES 
    ('e0000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000001', 'CHARGING')
ON CONFLICT (id) DO NOTHING;

INSERT INTO charging_port (id, station_service_id, power_type, power_kw, port_count)
VALUES 
    ('a0000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000007', 'DC', 50.0, 4),
    ('a0000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000007', 'AC', 22.0, 2)
ON CONFLICT (id) DO NOTHING;

-- Services for Station 2
INSERT INTO station_service (id, station_version_id, service_type)
VALUES 
    ('e0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000002', 'CHARGING')
ON CONFLICT (id) DO NOTHING;

INSERT INTO charging_port (id, station_service_id, power_type, power_kw, port_count)
VALUES 
    ('a0000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000008', 'DC', 150.0, 2),
    ('a0000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'AC', 11.0, 4)
ON CONFLICT (id) DO NOTHING;

-- Services for Station 3
INSERT INTO station_service (id, station_version_id, service_type)
VALUES 
    ('e0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000003', 'CHARGING')
ON CONFLICT (id) DO NOTHING;

INSERT INTO charging_port (id, station_service_id, power_type, power_kw, port_count)
VALUES 
    ('a0000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000009', 'DC', 100.0, 3),
    ('a0000000-0000-0000-0000-000000000010', 'e0000000-0000-0000-0000-000000000009', 'AC', 22.0, 3)
ON CONFLICT (id) DO NOTHING;

-- Services for Station 4
INSERT INTO station_service (id, station_version_id, service_type)
VALUES 
    ('e0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000004', 'CHARGING')
ON CONFLICT (id) DO NOTHING;

INSERT INTO charging_port (id, station_service_id, power_type, power_kw, port_count)
VALUES 
    ('a0000000-0000-0000-0000-000000000011', 'e0000000-0000-0000-0000-000000000010', 'DC', 50.0, 2),
    ('a0000000-0000-0000-0000-000000000012', 'e0000000-0000-0000-0000-000000000010', 'AC', 7.4, 4)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 6. AUDIT LOGS (for verification tasks)
-- ============================================

INSERT INTO audit_log (id, actor_id, actor_role, action, entity_type, entity_id, metadata, created_at)
VALUES 
    -- Task creation logs
    ('b0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'ADMIN', 'CREATE_VERIFICATION_TASK', 'VERIFICATION_TASK', 'f0000000-0000-0000-0000-000000000001', '{"stationId":"a0000000-0000-0000-0000-000000000001","priority":5}'::jsonb, NOW() - INTERVAL '2 days'),
    ('b0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'ADMIN', 'CREATE_VERIFICATION_TASK', 'VERIFICATION_TASK', 'f0000000-0000-0000-0000-000000000002', '{"stationId":"a0000000-0000-0000-0000-000000000002","priority":5}'::jsonb, NOW() - INTERVAL '3 days'),
    
    -- Task assignment logs
    ('b0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'ADMIN', 'ASSIGN_VERIFICATION_TASK', 'VERIFICATION_TASK', 'f0000000-0000-0000-0000-000000000003', '{"collaboratorUserId":"10000000-0000-0000-0000-000000000001"}'::jsonb, NOW() - INTERVAL '1 day'),
    
    -- Check-in logs (done by collaborator, but logged here for reference)
    ('b0000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000002', 'COLLABORATOR', 'CHECK_IN_VERIFICATION_TASK', 'VERIFICATION_TASK', 'f0000000-0000-0000-0000-000000000004', '{"distanceM":50}'::jsonb, NOW() - INTERVAL '6 hours'),
    
    -- Evidence submission logs
    ('b0000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', 'COLLABORATOR', 'SUBMIT_EVIDENCE', 'VERIFICATION_TASK', 'f0000000-0000-0000-0000-000000000005', '{"evidenceCount":3}'::jsonb, NOW() - INTERVAL '1 day'),
    
    -- Review logs
    ('b0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000001', 'ADMIN', 'REVIEW_VERIFICATION_TASK', 'VERIFICATION_TASK', 'f0000000-0000-0000-0000-000000000006', '{"result":"PASS"}'::jsonb, NOW() - INTERVAL '3 days'),
    ('b0000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', 'ADMIN', 'REVIEW_VERIFICATION_TASK', 'VERIFICATION_TASK', 'f0000000-0000-0000-0000-000000000007', '{"result":"FAIL"}'::jsonb, NOW() - INTERVAL '6 days')
ON CONFLICT (id) DO NOTHING;

