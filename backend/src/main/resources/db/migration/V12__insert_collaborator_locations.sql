-- Insert collaborator profiles with locations spread near different stations
-- Each collaborator is positioned near a different station for testing distance-based assignment

-- First, create all collaborator user accounts
INSERT INTO user_account (id, email, password_hash, role, status, created_at)
VALUES 
    ('10000000-0000-0000-0000-000000000001', 'collab1@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'COLLABORATOR', 'ACTIVE', NOW()),
    ('10000000-0000-0000-0000-000000000002', 'collab2@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'COLLABORATOR', 'ACTIVE', NOW()),
    ('10000000-0000-0000-0000-000000000003', 'collab3@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'COLLABORATOR', 'ACTIVE', NOW()),
    ('10000000-0000-0000-0000-000000000004', 'collab4@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'COLLABORATOR', 'ACTIVE', NOW()),
    ('10000000-0000-0000-0000-000000000005', 'collab5@local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'COLLABORATOR', 'ACTIVE', NOW())
ON CONFLICT (id) DO NOTHING;

-- Create collaborator profiles for all users
INSERT INTO collaborator_profile (id, user_account_id, full_name, phone, created_at)
VALUES 
    ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Nguyen Van Collab1', '0901234567', NOW()),
    ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Tran Thi Collab2', '0912345678', NOW()),
    ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'Le Van Collab3', '0923456789', NOW()),
    ('30000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000004', 'Pham Thi Collab4', '0934567890', NOW()),
    ('30000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000005', 'Hoang Van Collab5', '0945678901', NOW())
ON CONFLICT (user_account_id) DO NOTHING;

-- Update collaborator locations - All in Hanoi districts:
-- Station 1 (Hoàn Kiếm): 105.8542, 21.0285
-- Station 2 (Ba Đình): 105.8170, 21.0340
-- Station 3 (Cầu Giấy): 105.7900, 21.0380
-- Station 4 (Tây Hồ): 105.8230, 21.0680

-- Collab1: Quận Hoàn Kiếm - gần Station 1 (300m away)
UPDATE collaborator_profile 
SET 
    current_location = ST_SetSRID(ST_MakePoint(105.8570, 21.0300), 4326),
    location_updated_at = NOW() - INTERVAL '1 hour',
    location_source = 'MOBILE'
WHERE user_account_id = '10000000-0000-0000-0000-000000000001';

-- Collab2: Quận Ba Đình - gần Station 2 (500m away)
UPDATE collaborator_profile 
SET 
    current_location = ST_SetSRID(ST_MakePoint(105.8200, 21.0380), 4326),
    location_updated_at = NOW() - INTERVAL '2 hours',
    location_source = 'MOBILE'
WHERE user_account_id = '10000000-0000-0000-0000-000000000002';

-- Collab3: Quận Đống Đa (1.5km from Station 1)
UPDATE collaborator_profile 
SET 
    current_location = ST_SetSRID(ST_MakePoint(105.8280, 21.0167), 4326),
    location_updated_at = NOW() - INTERVAL '30 minutes',
    location_source = 'MOBILE'
WHERE user_account_id = '10000000-0000-0000-0000-000000000003';

-- Collab4: Quận Cầu Giấy - gần Station 3 (400m away)
UPDATE collaborator_profile 
SET 
    current_location = ST_SetSRID(ST_MakePoint(105.7930, 21.0400), 4326),
    location_updated_at = NOW() - INTERVAL '15 minutes',
    location_source = 'MOBILE'
WHERE user_account_id = '10000000-0000-0000-0000-000000000004';

-- Collab5: Quận Long Biên (xa nhất - 3km from center) - contract expired
UPDATE collaborator_profile 
SET 
    current_location = ST_SetSRID(ST_MakePoint(105.8890, 21.0450), 4326),
    location_updated_at = NOW() - INTERVAL '3 hours',
    location_source = 'WEB'
WHERE user_account_id = '10000000-0000-0000-0000-000000000005';

-- Create contracts for all collaborators - All in Hanoi (some active, one expired)
INSERT INTO contract (id, collaborator_id, region, start_date, end_date, status, created_at)
VALUES 
    -- Active contract for Collab1 - Hoàn Kiếm
    ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'HANOI', CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE + INTERVAL '335 days', 'ACTIVE', NOW()),
    -- Active contract for Collab2 - Ba Đình
    ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 'HANOI', CURRENT_DATE - INTERVAL '60 days', CURRENT_DATE + INTERVAL '305 days', 'ACTIVE', NOW()),
    -- Active contract for Collab3 - Đống Đa
    ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', 'HANOI', CURRENT_DATE - INTERVAL '15 days', CURRENT_DATE + INTERVAL '350 days', 'ACTIVE', NOW()),
    -- Active contract for Collab4 - Cầu Giấy
    ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000004', 'HANOI', CURRENT_DATE - INTERVAL '90 days', CURRENT_DATE + INTERVAL '275 days', 'ACTIVE', NOW()),
    -- EXPIRED contract for Collab5 - Long Biên (to test filtering)
    ('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000005', 'HANOI', CURRENT_DATE - INTERVAL '365 days', CURRENT_DATE - INTERVAL '1 day', 'ACTIVE', NOW())
ON CONFLICT (id) DO NOTHING;

-- Add audit log for location updates - All Hanoi locations
INSERT INTO audit_log (id, actor_id, actor_role, action, entity_type, entity_id, metadata, created_at)
VALUES 
    ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'COLLABORATOR', 'UPDATE_COLLABORATOR_LOCATION', 'COLLABORATOR_PROFILE', '30000000-0000-0000-0000-000000000001', '{"lat":21.0300,"lng":105.8570,"source":"MOBILE"}'::jsonb, NOW() - INTERVAL '1 hour'),
    ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'COLLABORATOR', 'UPDATE_COLLABORATOR_LOCATION', 'COLLABORATOR_PROFILE', '30000000-0000-0000-0000-000000000002', '{"lat":21.0380,"lng":105.8200,"source":"MOBILE"}'::jsonb, NOW() - INTERVAL '2 hours'),
    ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'COLLABORATOR', 'UPDATE_COLLABORATOR_LOCATION', 'COLLABORATOR_PROFILE', '30000000-0000-0000-0000-000000000003', '{"lat":21.0167,"lng":105.8280,"source":"MOBILE"}'::jsonb, NOW() - INTERVAL '30 minutes'),
    ('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000004', 'COLLABORATOR', 'UPDATE_COLLABORATOR_LOCATION', 'COLLABORATOR_PROFILE', '30000000-0000-0000-0000-000000000004', '{"lat":21.0400,"lng":105.7930,"source":"MOBILE"}'::jsonb, NOW() - INTERVAL '15 minutes'),
    ('50000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000005', 'COLLABORATOR', 'UPDATE_COLLABORATOR_LOCATION', 'COLLABORATOR_PROFILE', '30000000-0000-0000-0000-000000000005', '{"lat":21.0450,"lng":105.8890,"source":"WEB"}'::jsonb, NOW() - INTERVAL '3 hours')
ON CONFLICT (id) DO NOTHING;

