-- Add location tracking fields to collaborator_profile table
-- Supports GPS updates from collaborator mobile and manual updates from web

-- Create location source enum
CREATE TYPE location_source AS ENUM ('MOBILE', 'WEB');

-- Add location columns to collaborator_profile
ALTER TABLE collaborator_profile
    ADD COLUMN current_location geography(Point, 4326),
    ADD COLUMN location_updated_at TIMESTAMP,
    ADD COLUMN location_source location_source;

-- Create GiST index on current_location for spatial queries
CREATE INDEX idx_collaborator_profile_location 
    ON collaborator_profile USING GIST (current_location);

-- Index for verification task statistics (if not exists)
CREATE INDEX IF NOT EXISTS idx_verification_task_assigned_status 
    ON verification_task(assigned_to, status);

CREATE INDEX IF NOT EXISTS idx_verification_task_created_at 
    ON verification_task(created_at);

-- Comments for documentation
COMMENT ON COLUMN collaborator_profile.current_location IS 'Current GPS location of collaborator (geography Point, SRID 4326)';
COMMENT ON COLUMN collaborator_profile.location_updated_at IS 'Timestamp when location was last updated';
COMMENT ON COLUMN collaborator_profile.location_source IS 'Source of the location update: MOBILE (GPS) or WEB (manual)';

