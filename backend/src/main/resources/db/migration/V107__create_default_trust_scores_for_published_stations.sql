-- Create default trust scores (50) for all published stations that don't have trust scores yet
-- This ensures all published stations have a trust score

INSERT INTO station_trust (station_id, score, breakdown, updated_at)
SELECT DISTINCT sv.station_id, 50, '{"base": 50, "verification_bonus": 0, "issues_penalty": 0, "high_risk_penalty": 0}'::jsonb, NOW()
FROM station_version sv
WHERE sv.workflow_status = 'PUBLISHED'
  AND sv.station_id NOT IN (SELECT station_id FROM station_trust)
ON CONFLICT (station_id) DO NOTHING;

-- Add comment
COMMENT ON TABLE station_trust IS 'Trust scores for stations with explainable breakdown. Default score is 50 for new stations.';

