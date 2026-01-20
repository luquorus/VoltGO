-- Demo: User collab1@local đã verification task được giao
-- Thêm checkin đúng tọa độ, submit evidence, và review PASS (bỏ qua bước admin duyệt)

-- ============================================
-- Bước 1: Tìm task ID từ station ID và user collab1@local
-- ============================================
-- Station ID từ hình: 4ab537bc-b11d-49df-aa7d-d0b0b88d4d51
-- User ID của collab1@local: 10000000-0000-0000-0000-000000000001

DO $$
DECLARE
    v_task_id UUID;
    v_station_id UUID := '4ab537bc-b11d-49df-aa7d-d0b0b88d4d51';
    v_collab_user_id UUID := '10000000-0000-0000-0000-000000000001';
    v_admin_user_id UUID := '00000000-0000-0000-0000-000000000001'; -- admin@local
    v_station_lat NUMERIC(10,7);
    v_station_lng NUMERIC(10,7);
    v_checkin_lat NUMERIC(10,7);
    v_checkin_lng NUMERIC(10,7);
    v_distance_m INTEGER;
    v_checkin_id UUID;
    v_evidence_id1 UUID;
    v_evidence_id2 UUID;
    v_review_id UUID;
    v_audit_log_id UUID;
BEGIN
    -- Tìm task được assign cho collab1@local với station_id này
    SELECT id INTO v_task_id
    FROM verification_task
    WHERE station_id = v_station_id
      AND assigned_to = v_collab_user_id
      AND status = 'ASSIGNED'
    LIMIT 1;

    -- Nếu không tìm thấy task, tạo mới
    IF v_task_id IS NULL THEN
        v_task_id := gen_random_uuid();
        
        INSERT INTO verification_task (
            id, station_id, change_request_id, priority, sla_due_at,
            assigned_to, status, created_at
        )
        VALUES (
            v_task_id,
            v_station_id,
            NULL,
            3,
            NOW() + INTERVAL '24 hours',
            v_collab_user_id,
            'ASSIGNED',
            NOW() - INTERVAL '1 day'
        );
        
        RAISE NOTICE 'Created new task: %', v_task_id;
    ELSE
        RAISE NOTICE 'Found existing task: %', v_task_id;
    END IF;

    -- ============================================
    -- Bước 2: Lấy tọa độ station từ published version
    -- ============================================
    SELECT 
        ST_Y(CAST(location AS geometry))::NUMERIC(10,7),
        ST_X(CAST(location AS geometry))::NUMERIC(10,7)
    INTO v_station_lat, v_station_lng
    FROM station_version
    WHERE station_id = v_station_id
      AND workflow_status = 'PUBLISHED'
    LIMIT 1;

    IF v_station_lat IS NULL OR v_station_lng IS NULL THEN
        RAISE EXCEPTION 'Station % not found or not published', v_station_id;
    END IF;

    RAISE NOTICE 'Station location: lat=%, lng=%', v_station_lat, v_station_lng;

    -- ============================================
    -- Bước 3: Tạo checkin với tọa độ gần station (trong 200m)
    -- ============================================
    -- Thêm một chút offset nhỏ để giống như GPS thực tế (khoảng 30-50m)
    -- 1 độ latitude ≈ 111km, 1 độ longitude ≈ 111km * cos(latitude)
    -- Để có 50m: 50/111000 ≈ 0.00045 độ
    v_checkin_lat := v_station_lat + (RANDOM() * 0.0009 - 0.00045); -- ±0.00045 = ~±50m
    v_checkin_lng := v_station_lng + (RANDOM() * 0.0009 / COS(RADIANS(v_station_lat)) - 0.00045 / COS(RADIANS(v_station_lat)));

    -- Tính khoảng cách thực tế
    SELECT CAST(ST_Distance(
        CAST(location AS geography),
        CAST(ST_SetSRID(ST_MakePoint(v_checkin_lng, v_checkin_lat), 4326) AS geography)
    ) AS INTEGER)
    INTO v_distance_m
    FROM station_version
    WHERE station_id = v_station_id
      AND workflow_status = 'PUBLISHED';

    -- Đảm bảo distance < 200m
    IF v_distance_m > 200 THEN
        -- Điều chỉnh lại để gần hơn
        v_checkin_lat := v_station_lat;
        v_checkin_lng := v_station_lng;
        v_distance_m := 0;
    END IF;

    v_checkin_id := gen_random_uuid();

    INSERT INTO verification_checkin (
        id, task_id, checkin_lat, checkin_lng, checked_in_at, distance_m, device_note
    )
    VALUES (
        v_checkin_id,
        v_task_id,
        v_checkin_lat,
        v_checkin_lng,
        NOW() - INTERVAL '2 hours', -- Checkin 2 giờ trước
        v_distance_m,
        'GPS accuracy: 10m, device: iPhone 15 Pro'
    )
    ON CONFLICT (task_id) DO UPDATE
    SET checkin_lat = EXCLUDED.checkin_lat,
        checkin_lng = EXCLUDED.checkin_lng,
        checked_in_at = EXCLUDED.checked_in_at,
        distance_m = EXCLUDED.distance_m,
        device_note = EXCLUDED.device_note;

    RAISE NOTICE 'Checkin created: lat=%, lng=%, distance=%m', v_checkin_lat, v_checkin_lng, v_distance_m;

    -- ============================================
    -- Bước 4: Update task status thành CHECKED_IN
    -- ============================================
    UPDATE verification_task
    SET status = 'CHECKED_IN'
    WHERE id = v_task_id;

    -- Audit log cho checkin
    v_audit_log_id := gen_random_uuid();
    INSERT INTO audit_log (
        id, actor_id, actor_role, action, entity_type, entity_id, metadata, created_at
    )
    VALUES (
        v_audit_log_id,
        v_collab_user_id,
        'COLLABORATOR',
        'CHECKIN_VERIFICATION_TASK',
        'VERIFICATION_TASK',
        v_task_id,
        jsonb_build_object(
            'lat', v_checkin_lat,
            'lng', v_checkin_lng,
            'distance_m', v_distance_m,
            'stationId', v_station_id::text
        ),
        NOW() - INTERVAL '2 hours'
    );

    -- ============================================
    -- Bước 5: Insert evidence (ảnh)
    -- ============================================
    v_evidence_id1 := gen_random_uuid();
    v_evidence_id2 := gen_random_uuid();

    INSERT INTO verification_evidence (
        id, task_id, photo_object_key, note, submitted_at, submitted_by
    )
    VALUES 
        (
            v_evidence_id1,
            v_task_id,
            'evidence/2025/task-' || SUBSTRING(v_task_id::text, 1, 8) || '/photo-1.jpg',
            'Front view of charging station',
            NOW() - INTERVAL '1 hour',
            v_collab_user_id
        ),
        (
            v_evidence_id2,
            v_task_id,
            'evidence/2025/task-' || SUBSTRING(v_task_id::text, 1, 8) || '/photo-2.jpg',
            'Side view showing charging ports and signage',
            NOW() - INTERVAL '1 hour',
            v_collab_user_id
        )
    ON CONFLICT (id) DO NOTHING;

    RAISE NOTICE 'Evidence inserted: 2 photos';

    -- ============================================
    -- Bước 6: Update task status thành SUBMITTED
    -- ============================================
    UPDATE verification_task
    SET status = 'SUBMITTED'
    WHERE id = v_task_id;

    -- Audit log cho submit evidence
    v_audit_log_id := gen_random_uuid();
    INSERT INTO audit_log (
        id, actor_id, actor_role, action, entity_type, entity_id, metadata, created_at
    )
    VALUES (
        v_audit_log_id,
        v_collab_user_id,
        'COLLABORATOR',
        'SUBMIT_EVIDENCE',
        'VERIFICATION_TASK',
        v_task_id,
        jsonb_build_object('evidenceCount', 2),
        NOW() - INTERVAL '1 hour'
    );

    -- ============================================
    -- Bước 7: Insert review với result PASS (bỏ qua bước admin duyệt)
    -- ============================================
    v_review_id := gen_random_uuid();

    INSERT INTO verification_review (
        id, task_id, result, admin_note, reviewed_at, reviewed_by
    )
    VALUES (
        v_review_id,
        v_task_id,
        'PASS',
        'Verification completed successfully. Location accurate, evidence provided.',
        NOW(),
        v_admin_user_id
    )
    ON CONFLICT (task_id) DO UPDATE
    SET result = EXCLUDED.result,
        admin_note = EXCLUDED.admin_note,
        reviewed_at = EXCLUDED.reviewed_at,
        reviewed_by = EXCLUDED.reviewed_by;

    -- ============================================
    -- Bước 8: Update task status thành REVIEWED
    -- ============================================
    UPDATE verification_task
    SET status = 'REVIEWED'
    WHERE id = v_task_id;

    -- Audit log cho review
    v_audit_log_id := gen_random_uuid();
    INSERT INTO audit_log (
        id, actor_id, actor_role, action, entity_type, entity_id, metadata, created_at
    )
    VALUES (
        v_audit_log_id,
        v_admin_user_id,
        'ADMIN',
        'REVIEW_VERIFICATION_TASK',
        'VERIFICATION_TASK',
        v_task_id,
        jsonb_build_object(
            'result', 'PASS',
            'adminNote', 'Verification completed successfully. Location accurate, evidence provided.',
            'stationId', v_station_id::text
        ),
        NOW()
    );

    -- ============================================
    -- Bước 9: Recalculate trust score (gọi service nếu có trigger)
    -- ============================================
    -- Trust score sẽ được tính lại khi review PASS
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Verification task completed successfully!';
    RAISE NOTICE 'Task ID: %', v_task_id;
    RAISE NOTICE 'Status: ASSIGNED -> CHECKED_IN -> SUBMITTED -> REVIEWED';
    RAISE NOTICE 'Review Result: PASS';
    RAISE NOTICE '========================================';

END $$;

