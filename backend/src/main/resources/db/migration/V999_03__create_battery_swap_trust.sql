-- ============================================================
-- V999_03__create_battery_swap_trust.sql
-- Creates table for battery swap station trust scores
-- ============================================================

-- Battery Swap Trust - tracks trust scores for battery swap stations
CREATE TABLE battery_swap_trust (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id      UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    score           INTEGER NOT NULL DEFAULT 50,
    breakdown       JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_event_at   TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_bst_station UNIQUE (station_id),
    CONSTRAINT ck_bst_score CHECK (score >= 0 AND score <= 100)
);

CREATE INDEX idx_bst_score ON battery_swap_trust(score DESC);
CREATE INDEX idx_bst_station ON battery_swap_trust(station_id);
CREATE INDEX idx_bst_updated ON battery_swap_trust(updated_at DESC);
