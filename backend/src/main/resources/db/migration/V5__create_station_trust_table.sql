-- Station Trust Score table for tracking trust scores with explainable breakdown

CREATE TABLE station_trust (
    station_id UUID PRIMARY KEY REFERENCES station(id) ON DELETE CASCADE,
    score INTEGER NOT NULL DEFAULT 50,
    breakdown JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Check constraint: score must be between 0 and 100
    CONSTRAINT ck_station_trust_score_range CHECK (score >= 0 AND score <= 100)
);

-- Index for fast lookup
CREATE INDEX idx_station_trust_score ON station_trust(score);
CREATE INDEX idx_station_trust_updated_at ON station_trust(updated_at DESC);

-- Comments for documentation
COMMENT ON TABLE station_trust IS 'Trust scores for stations with explainable breakdown';
COMMENT ON COLUMN station_trust.score IS 'Trust score from 0 to 100';
COMMENT ON COLUMN station_trust.breakdown IS 'JSON breakdown: base, verification_bonus, issues_penalty, high_risk_penalty';
COMMENT ON COLUMN station_trust.updated_at IS 'Last time trust score was recalculated';

