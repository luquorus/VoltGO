-- ============================================================
-- V999_02__create_battery_swap_change_request.sql
-- Creates table for battery swap change requests
-- ============================================================

-- Battery Swap Change Request - tracks changes to battery swap station configurations
CREATE TABLE battery_swap_change_request (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type                  VARCHAR(30) NOT NULL,
    status                VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    station_id            UUID REFERENCES station(id) ON DELETE SET NULL,
    proposed_version_id   UUID NOT NULL REFERENCES battery_swap_station_version(id),
    submitted_by          UUID NOT NULL,
    risk_score            INTEGER NOT NULL DEFAULT 0,
    risk_reasons          JSONB DEFAULT '[]'::jsonb,
    admin_note            TEXT,
    created_at            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    submitted_at          TIMESTAMP WITH TIME ZONE,
    decided_at            TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uk_bscr_proposed_version UNIQUE (proposed_version_id)
);

CREATE INDEX idx_bscr_station ON battery_swap_change_request(station_id);
CREATE INDEX idx_bscr_status ON battery_swap_change_request(status);
CREATE INDEX idx_bscr_submitted ON battery_swap_change_request(submitted_by);
