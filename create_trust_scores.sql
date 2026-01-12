-- Insert trust scores for all stations that don't have one yet
-- Base score: 50, with default breakdown
INSERT INTO station_trust (station_id, score, breakdown, updated_at)
SELECT 
    s.id,
    50,
    '{"base": 50, "verificationBonus": 0, "issuesPenalty": 0, "highRiskPenalty": 0}'::jsonb,
    NOW()
FROM station s
WHERE NOT EXISTS (
    SELECT 1 FROM station_trust st WHERE st.station_id = s.id
)
RETURNING station_id, score;

