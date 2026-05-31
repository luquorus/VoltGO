DO $$
DECLARE
  v_admin_id UUID;
  v_station_id UUID := gen_random_uuid();
  v_version_id UUID := gen_random_uuid();
  v_task_id    UUID := gen_random_uuid();
  v_collab_id  UUID := '10000000-0000-0000-0000-000000000001';
BEGIN
  -- Lay admin ID
  SELECT id INTO v_admin_id FROM user_account WHERE role = 'ADMIN' LIMIT 1;

  -- Tao station
  INSERT INTO station (id, provider_id, created_at)
  VALUES (v_station_id, v_admin_id, NOW());

  -- Tao station_version PUBLISHED tai toa do collab (20.990158, 105.855614)
  INSERT INTO station_version (id, station_id, version_no, workflow_status, name, address, location, parking, visibility, public_status, created_by, created_at, published_at)
  VALUES (
    v_version_id,
    v_station_id,
    1,
    'PUBLISHED',
    'Tram Test Gan Collab HN',
    'So 1 Test, Ha Noi',
    ST_SetSRID(ST_MakePoint(105.855614, 20.990158), 4326),
    'UNKNOWN',
    'PUBLIC',
    'ACTIVE',
    v_admin_id,
    NOW(),
    NOW()
  );

  -- Tao verification_task ASSIGNED cho collab1@local
  INSERT INTO verification_task (id, station_id, priority, assigned_to, status, created_at)
  VALUES (v_task_id, v_station_id, 3, v_collab_id, 'ASSIGNED', NOW());

  INSERT INTO battery_swap_station_state (
    station_id, total_batteries, available_batteries, avg_charge_power_kw, updated_at
  )
  VALUES (v_station_id, 20, 10, 35.0, NOW())
  ON CONFLICT (station_id) DO NOTHING;

  RAISE NOTICE 'Done! station_id=%, task_id=%', v_station_id, v_task_id;
END;
$$;
