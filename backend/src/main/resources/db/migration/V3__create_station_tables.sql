-- Create enums
CREATE TYPE workflow_status AS ENUM ('DRAFT', 'PENDING', 'PUBLISHED', 'REJECTED', 'ARCHIVED');
CREATE TYPE parking_type AS ENUM ('PAID', 'FREE', 'UNKNOWN');
CREATE TYPE visibility_type AS ENUM ('PUBLIC', 'PRIVATE', 'RESTRICTED');
CREATE TYPE public_status_type AS ENUM ('ACTIVE', 'INACTIVE', 'MAINTENANCE');
CREATE TYPE service_type AS ENUM ('CHARGING', 'BATTERY_SWAP');
CREATE TYPE change_request_type AS ENUM ('CREATE_STATION', 'UPDATE_STATION');
CREATE TYPE change_request_status AS ENUM ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'PUBLISHED');
CREATE TYPE power_type AS ENUM ('DC', 'AC');

-- 1. station table
CREATE TABLE station (
    id UUID PRIMARY KEY,
    provider_id UUID REFERENCES user_account(id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_station_provider_id ON station(provider_id);

-- 2. station_version table
CREATE TABLE station_version (
    id UUID PRIMARY KEY,
    station_id UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL,
    workflow_status workflow_status NOT NULL DEFAULT 'DRAFT',
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    location geography(Point,4326) NOT NULL,
    operating_hours TEXT,
    parking parking_type NOT NULL DEFAULT 'UNKNOWN',
    visibility visibility_type NOT NULL DEFAULT 'PUBLIC',
    public_status public_status_type NOT NULL DEFAULT 'ACTIVE',
    created_by UUID NOT NULL REFERENCES user_account(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    published_at TIMESTAMP,
    
    -- Unique constraint: (station_id, version_no)
    CONSTRAINT uk_station_version_station_id_version_no UNIQUE (station_id, version_no),
    
    -- Check constraints
    CONSTRAINT ck_station_version_version_no_positive CHECK (version_no > 0),
    CONSTRAINT ck_station_version_published_at_when_published 
        CHECK ((workflow_status = 'PUBLISHED' AND published_at IS NOT NULL) 
               OR (workflow_status != 'PUBLISHED' AND published_at IS NULL))
);

-- Partial unique index: only 1 PUBLISHED version per station
CREATE UNIQUE INDEX idx_station_version_one_published 
    ON station_version(station_id) 
    WHERE workflow_status = 'PUBLISHED';

-- GiST index on geography location for spatial queries
CREATE INDEX idx_station_version_location_gist ON station_version USING GIST(location);

-- Indexes for common queries
CREATE INDEX idx_station_version_station_id ON station_version(station_id);
CREATE INDEX idx_station_version_workflow_status ON station_version(workflow_status);
CREATE INDEX idx_station_version_created_by ON station_version(created_by);

-- 3. station_service table
CREATE TABLE station_service (
    id UUID PRIMARY KEY,
    station_version_id UUID NOT NULL REFERENCES station_version(id) ON DELETE CASCADE,
    service_type service_type NOT NULL DEFAULT 'CHARGING'
);

CREATE INDEX idx_station_service_station_version_id ON station_service(station_version_id);
CREATE INDEX idx_station_service_type ON station_service(service_type);

-- 4. charging_port table
CREATE TABLE charging_port (
    id UUID PRIMARY KEY,
    station_service_id UUID NOT NULL REFERENCES station_service(id) ON DELETE CASCADE,
    power_type power_type NOT NULL,
    power_kw NUMERIC,
    port_count INTEGER NOT NULL DEFAULT 1,
    
    -- Check constraints
    CONSTRAINT ck_charging_port_port_count_positive CHECK (port_count >= 0),
    CONSTRAINT ck_charging_port_power_kw_when_dc 
        CHECK ((power_type = 'DC' AND power_kw IS NOT NULL AND power_kw > 0) 
               OR (power_type = 'AC'))
);

CREATE INDEX idx_charging_port_station_service_id ON charging_port(station_service_id);
CREATE INDEX idx_charging_port_power_type ON charging_port(power_type);

-- 5. change_request table
CREATE TABLE change_request (
    id UUID PRIMARY KEY,
    type change_request_type NOT NULL,
    status change_request_status NOT NULL DEFAULT 'DRAFT',
    station_id UUID REFERENCES station(id) ON DELETE CASCADE,
    proposed_station_version_id UUID NOT NULL REFERENCES station_version(id) ON DELETE CASCADE,
    submitted_by UUID NOT NULL REFERENCES user_account(id),
    risk_score INTEGER NOT NULL DEFAULT 0,
    risk_reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
    admin_note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMP,
    decided_at TIMESTAMP,
    
    -- Check constraints
    CONSTRAINT ck_change_request_station_id_when_update 
        CHECK ((type = 'UPDATE_STATION' AND station_id IS NOT NULL) 
               OR (type = 'CREATE_STATION' AND station_id IS NULL)),
    CONSTRAINT ck_change_request_risk_score_range CHECK (risk_score >= 0 AND risk_score <= 100),
    CONSTRAINT ck_change_request_submitted_at_when_pending 
        CHECK ((status IN ('PENDING', 'APPROVED', 'REJECTED', 'PUBLISHED') AND submitted_at IS NOT NULL) 
               OR (status = 'DRAFT' AND submitted_at IS NULL)),
    CONSTRAINT ck_change_request_decided_at_when_decided 
        CHECK ((status IN ('APPROVED', 'REJECTED', 'PUBLISHED') AND decided_at IS NOT NULL) 
               OR (status IN ('DRAFT', 'PENDING') AND decided_at IS NULL))
);

CREATE INDEX idx_change_request_station_id ON change_request(station_id);
CREATE INDEX idx_change_request_status ON change_request(status);
CREATE INDEX idx_change_request_submitted_by ON change_request(submitted_by);
CREATE INDEX idx_change_request_proposed_station_version_id ON change_request(proposed_station_version_id);
CREATE INDEX idx_change_request_type ON change_request(type);

-- 6. audit_log table
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    actor_role TEXT NOT NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_actor_id ON audit_log(actor_id);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);
CREATE INDEX idx_audit_log_action ON audit_log(action);

-- Comments for documentation
COMMENT ON TABLE station IS 'Main station entity - represents a physical location';
COMMENT ON TABLE station_version IS 'Versioned station data following workflow (DRAFT -> PENDING -> PUBLISHED)';
COMMENT ON TABLE station_service IS 'Services available at a station (CHARGING or BATTERY_SWAP)';
COMMENT ON TABLE charging_port IS 'Charging port configurations (power type, power level, count)';
COMMENT ON TABLE change_request IS 'Change requests for station creation/updates with review workflow';
COMMENT ON TABLE audit_log IS 'Audit trail for all system actions';

COMMENT ON INDEX idx_station_version_one_published IS 'Ensures only 1 PUBLISHED version exists per station at any time';
COMMENT ON INDEX idx_station_version_location_gist IS 'GiST index for efficient spatial queries on location';

