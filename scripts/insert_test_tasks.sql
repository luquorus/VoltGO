-- Script to insert test verification tasks for collaborator testcollab@voltgo.com
-- Run this in PostgreSQL container: docker exec -i voltgo-postgres psql -U voltgo_user -d voltgo < scripts/insert_test_tasks.sql

-- First, get the collaborator user ID (assuming testcollab@voltgo.com exists)
-- If not exists, create it first
DO $$
DECLARE
    v_collab_user_id UUID;
    v_station_id UUID;
    v_task_id UUID;
BEGIN
    -- Get or create collaborator user
    SELECT id INTO v_collab_user_id
    FROM user_account
    WHERE email = 'testcollab@voltgo.com';
    
    IF v_collab_user_id IS NULL THEN
        -- Create collaborator user if not exists
        v_collab_user_id := gen_random_uuid();
        INSERT INTO user_account (id, email, password_hash, role, status, created_at)
        VALUES (
            v_collab_user_id,
            'testcollab@voltgo.com',
            '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', -- Password: Test@123
            'COLLABORATOR',
            'ACTIVE',
            NOW()
        );
        RAISE NOTICE 'Created collaborator user: %', v_collab_user_id;
    ELSE
        RAISE NOTICE 'Found existing collaborator user: %', v_collab_user_id;
    END IF;
    
    -- Get a station ID (use first available station or create one)
    SELECT id INTO v_station_id
    FROM station
    LIMIT 1;
    
    IF v_station_id IS NULL THEN
        -- Create a test station if none exists
        v_station_id := gen_random_uuid();
        INSERT INTO station (id, created_at)
        VALUES (v_station_id, NOW());
        
        -- Create a published station version
        INSERT INTO station_version (
            id, station_id, version_no, workflow_status, name, address,
            location, parking, visibility, public_status, created_by, created_at, published_at
        )
        VALUES (
            gen_random_uuid(),
            v_station_id,
            1,
            'PUBLISHED',
            'Test Charging Station',
            '123 Test Street, Ho Chi Minh City',
            ST_SetSRID(ST_MakePoint(106.6297, 10.8231), 4326), -- HCMC coordinates
            'FREE',
            'PUBLIC',
            'ACTIVE',
            (SELECT id FROM user_account WHERE role = 'ADMIN' LIMIT 1),
            NOW(),
            NOW()
        );
        RAISE NOTICE 'Created test station: %', v_station_id;
    ELSE
        RAISE NOTICE 'Using existing station: %', v_station_id;
    END IF;
    
    -- Insert test tasks with different statuses
    
    -- 1. ASSIGNED task (high priority, urgent SLA)
    v_task_id := gen_random_uuid();
    INSERT INTO verification_task (
        id, station_id, priority, sla_due_at, assigned_to, status, created_at
    )
    VALUES (
        v_task_id,
        v_station_id,
        5,
        NOW() + INTERVAL '2 hours',
        v_collab_user_id,
        'ASSIGNED',
        NOW() - INTERVAL '1 day'
    );
    RAISE NOTICE 'Created ASSIGNED task: %', v_task_id;
    
    -- 2. ASSIGNED task (medium priority)
    v_task_id := gen_random_uuid();
    INSERT INTO verification_task (
        id, station_id, priority, sla_due_at, assigned_to, status, created_at
    )
    VALUES (
        v_task_id,
        v_station_id,
        3,
        NOW() + INTERVAL '3 days',
        v_collab_user_id,
        'ASSIGNED',
        NOW() - INTERVAL '2 hours'
    );
    RAISE NOTICE 'Created ASSIGNED task: %', v_task_id;
    
    -- 3. CHECKED_IN task (with check-in record)
    v_task_id := gen_random_uuid();
    INSERT INTO verification_task (
        id, station_id, priority, sla_due_at, assigned_to, status, created_at
    )
    VALUES (
        v_task_id,
        v_station_id,
        4,
        NOW() + INTERVAL '1 day',
        v_collab_user_id,
        'CHECKED_IN',
        NOW() - INTERVAL '2 days'
    );
    
    -- Add check-in record
    INSERT INTO verification_checkin (
        task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
    )
    VALUES (
        v_task_id,
        10.8231,
        106.6297,
        NOW() - INTERVAL '1 hour',
        15,
        'Checked in successfully'
    );
    RAISE NOTICE 'Created CHECKED_IN task: %', v_task_id;
    
    -- 4. CHECKED_IN task (far from station)
    v_task_id := gen_random_uuid();
    INSERT INTO verification_task (
        id, station_id, priority, sla_due_at, assigned_to, status, created_at
    )
    VALUES (
        v_task_id,
        v_station_id,
        2,
        NOW() + INTERVAL '5 days',
        v_collab_user_id,
        'CHECKED_IN',
        NOW() - INTERVAL '1 day'
    );
    
    INSERT INTO verification_checkin (
        task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
    )
    VALUES (
        v_task_id,
        10.8250,
        106.6300,
        NOW() - INTERVAL '30 minutes',
        180,
        'Checked in - slightly far'
    );
    RAISE NOTICE 'Created CHECKED_IN task (far): %', v_task_id;
    
    -- 5. SUBMITTED task
    v_task_id := gen_random_uuid();
    INSERT INTO verification_task (
        id, station_id, priority, sla_due_at, assigned_to, status, created_at
    )
    VALUES (
        v_task_id,
        v_station_id,
        3,
        NOW() + INTERVAL '2 days',
        v_collab_user_id,
        'SUBMITTED',
        NOW() - INTERVAL '3 days'
    );
    
    INSERT INTO verification_checkin (
        task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
    )
    VALUES (
        v_task_id,
        10.8231,
        106.6297,
        NOW() - INTERVAL '2 days',
        25,
        'Checked in'
    );
    
    INSERT INTO verification_evidence (
        task_id, photo_object_key, note, submitted_at, submitted_by
    )
    VALUES (
        v_task_id,
        'evidence/test-evidence-1.jpg',
        'Station looks good',
        NOW() - INTERVAL '1 day',
        v_collab_user_id
    );
    RAISE NOTICE 'Created SUBMITTED task: %', v_task_id;
    
    -- 6. REVIEWED task (PASS)
    v_task_id := gen_random_uuid();
    INSERT INTO verification_task (
        id, station_id, priority, sla_due_at, assigned_to, status, created_at
    )
    VALUES (
        v_task_id,
        v_station_id,
        2,
        NOW() - INTERVAL '1 day',
        v_collab_user_id,
        'REVIEWED',
        NOW() - INTERVAL '7 days'
    );
    
    INSERT INTO verification_checkin (
        task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
    )
    VALUES (
        v_task_id,
        10.8231,
        106.6297,
        NOW() - INTERVAL '6 days',
        10,
        'Checked in'
    );
    
    INSERT INTO verification_evidence (
        task_id, photo_object_key, note, submitted_at, submitted_by
    )
    VALUES (
        v_task_id,
        'evidence/test-evidence-2.jpg',
        'All verified',
        NOW() - INTERVAL '5 days',
        v_collab_user_id
    );
    
    INSERT INTO verification_review (
        task_id, result, admin_note, reviewed_at, reviewed_by
    )
    VALUES (
        v_task_id,
        'PASS',
        'Verification completed successfully',
        NOW() - INTERVAL '2 days',
        (SELECT id FROM user_account WHERE role = 'ADMIN' LIMIT 1)
    );
    RAISE NOTICE 'Created REVIEWED task (PASS): %', v_task_id;
    
    -- 7. REVIEWED task (FAIL)
    v_task_id := gen_random_uuid();
    INSERT INTO verification_task (
        id, station_id, priority, sla_due_at, assigned_to, status, created_at
    )
    VALUES (
        v_task_id,
        v_station_id,
        4,
        NOW() - INTERVAL '3 days',
        v_collab_user_id,
        'REVIEWED',
        NOW() - INTERVAL '10 days'
    );
    
    INSERT INTO verification_checkin (
        task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
    )
    VALUES (
        v_task_id,
        10.8231,
        106.6297,
        NOW() - INTERVAL '9 days',
        30,
        'Checked in'
    );
    
    INSERT INTO verification_evidence (
        task_id, photo_object_key, note, submitted_at, submitted_by
    )
    VALUES (
        v_task_id,
        'evidence/test-evidence-3.jpg',
        'Some issues found',
        NOW() - INTERVAL '8 days',
        v_collab_user_id
    );
    
    INSERT INTO verification_review (
        task_id, result, admin_note, reviewed_at, reviewed_by
    )
    VALUES (
        v_task_id,
        'FAIL',
        'Location mismatch detected',
        NOW() - INTERVAL '5 days',
        (SELECT id FROM user_account WHERE role = 'ADMIN' LIMIT 1)
    );
    RAISE NOTICE 'Created REVIEWED task (FAIL): %', v_task_id;
    
    RAISE NOTICE 'All test tasks created successfully!';
END $$;

