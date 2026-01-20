-- Publish all station versions and create charger units from charging ports
-- This migration:
-- 1. Publishes all DRAFT/PENDING station versions to PUBLISHED
-- 2. Creates charger units from charging ports for all published stations

-- ============================================
-- 1. PUBLISH ALL STATION VERSIONS
-- ============================================

-- Update all DRAFT and PENDING station versions to PUBLISHED
-- Set published_at to current timestamp
UPDATE station_version
SET 
    workflow_status = 'PUBLISHED',
    published_at = COALESCE(published_at, NOW())
WHERE workflow_status IN ('DRAFT', 'PENDING')
  AND published_at IS NULL;

-- ============================================
-- 2. CREATE CHARGER UNITS FROM CHARGING PORTS
-- ============================================

-- For each published station_version, expand charging_ports into charger_units
-- Strategy: For each charging_port with port_count > 0, create port_count units
-- Only create if charger units don't already exist for this station_version

INSERT INTO charger_unit (id, station_id, station_version_id, power_type, power_kw, label, price_per_slot, status, created_at)
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
        WHEN cp.power_type = 'DC' AND cp.power_kw >= 200 THEN 30000  -- 250kW DC: 30k VND/slot (was 60k/hour)
        WHEN cp.power_type = 'DC' AND cp.power_kw >= 100 THEN 20000  -- 120kW DC: 20k VND/slot (was 40k/hour)
        WHEN cp.power_type = 'DC' THEN 15000                          -- Other DC: 15k VND/slot (was 30k/hour)
        ELSE 10000                                                    -- AC: 10k VND/slot (was 20k/hour)
    END as price_per_slot,
    'ACTIVE'::charger_unit_status as status,
    NOW() as created_at
FROM station_version sv
JOIN station_service ss ON ss.station_version_id = sv.id
JOIN charging_port cp ON cp.station_service_id = ss.id
CROSS JOIN LATERAL generate_series(1, cp.port_count) as unit_num
WHERE sv.workflow_status = 'PUBLISHED'
  -- Only create charger units if they don't already exist for this station_version
  AND NOT EXISTS (
      SELECT 1 FROM charger_unit cu 
      WHERE cu.station_version_id = sv.id
  )
ON CONFLICT (station_id, label) DO NOTHING;

-- ============================================
-- 3. VERIFY RESULTS
-- ============================================

-- Log summary (this will be visible in Flyway output)
DO $$
DECLARE
    published_count INTEGER;
    charger_unit_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO published_count
    FROM station_version
    WHERE workflow_status = 'PUBLISHED';
    
    SELECT COUNT(*) INTO charger_unit_count
    FROM charger_unit;
    
    RAISE NOTICE 'Migration V106 completed: Published % station versions, Created % charger units', 
        published_count, charger_unit_count;
END $$;

