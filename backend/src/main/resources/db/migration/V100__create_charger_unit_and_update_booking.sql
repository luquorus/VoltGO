-- Create charger_unit_status enum
CREATE TYPE charger_unit_status AS ENUM ('ACTIVE', 'INACTIVE', 'MAINTENANCE');

-- Create charger_unit table
CREATE TABLE charger_unit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    station_version_id UUID NOT NULL REFERENCES station_version(id) ON DELETE CASCADE,
    power_type power_type NOT NULL,
    power_kw NUMERIC,
    label TEXT NOT NULL,
    price_per_hour INTEGER NOT NULL CHECK (price_per_hour >= 0),
    status charger_unit_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Unique constraint: (station_id, label)
    CONSTRAINT uk_charger_unit_station_label UNIQUE (station_id, label),
    
    -- Check constraints
    CONSTRAINT ck_charger_unit_power_kw_when_dc 
        CHECK ((power_type = 'DC' AND power_kw IS NOT NULL AND power_kw > 0) 
               OR (power_type = 'AC'))
);

-- Indexes for charger_unit
CREATE INDEX idx_charger_unit_station_id ON charger_unit(station_id);
CREATE INDEX idx_charger_unit_station_power ON charger_unit(station_id, power_type, power_kw);
CREATE INDEX idx_charger_unit_status ON charger_unit(status) WHERE status = 'ACTIVE';
CREATE INDEX idx_charger_unit_station_version_id ON charger_unit(station_version_id);

-- Comments
COMMENT ON TABLE charger_unit IS 'Individual charger units (expand from charging_port) for booking';
COMMENT ON COLUMN charger_unit.label IS 'Unit label like DC250-01, DC250-02, AC-01';
COMMENT ON COLUMN charger_unit.price_per_hour IS 'Price in VND per hour';
COMMENT ON COLUMN charger_unit.status IS 'ACTIVE (bookable), INACTIVE, MAINTENANCE (not available)';

-- Enable btree_gist extension for exclusion constraints
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Delete existing bookings that don't have charger_unit (they're obsolete)
-- This is safe because charger_unit is a new feature
DELETE FROM booking;

-- Update booking table: add charger_unit_id, price_snapshot, time_range
ALTER TABLE booking 
    ADD COLUMN charger_unit_id UUID NOT NULL REFERENCES charger_unit(id) ON DELETE RESTRICT,
    ADD COLUMN price_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN time_range TSTZRANGE;

-- Populate time_range for existing rows (if any)
UPDATE booking SET time_range = TSTZRANGE(start_time, end_time, '[)');

-- Make time_range NOT NULL and add trigger to auto-update it
ALTER TABLE booking ALTER COLUMN time_range SET NOT NULL;

-- Create function to update time_range
CREATE OR REPLACE FUNCTION update_booking_time_range()
RETURNS TRIGGER AS $$
BEGIN
    NEW.time_range := TSTZRANGE(NEW.start_time, NEW.end_time, '[)');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update time_range
CREATE TRIGGER trigger_update_booking_time_range
    BEFORE INSERT OR UPDATE OF start_time, end_time ON booking
    FOR EACH ROW
    EXECUTE FUNCTION update_booking_time_range();

-- Add index on time_range for exclusion constraint (before adding constraint)
CREATE INDEX idx_booking_time_range ON booking USING GIST(charger_unit_id, time_range) 
    WHERE status IN ('HOLD', 'CONFIRMED');

-- Add exclusion constraint to prevent double-booking
-- Only HOLD and CONFIRMED bookings block slots
ALTER TABLE booking 
    ADD CONSTRAINT ck_booking_no_overlap_active 
    EXCLUDE USING GIST (
        charger_unit_id WITH =,
        time_range WITH &&
    ) 
    WHERE (status IN ('HOLD', 'CONFIRMED'));

-- Add index on charger_unit_id
CREATE INDEX idx_booking_charger_unit_id ON booking(charger_unit_id);

-- Update comments
COMMENT ON COLUMN booking.charger_unit_id IS 'Reference to specific charger unit being booked';
COMMENT ON COLUMN booking.price_snapshot IS 'JSON snapshot of pricing at booking time: {unitLabel, powerType, powerKw, pricePerHour, durationMinutes, amount}';
COMMENT ON COLUMN booking.time_range IS 'Generated time range for exclusion constraint';
COMMENT ON CONSTRAINT ck_booking_no_overlap_active ON booking IS 'Prevents overlapping bookings on same charger_unit when status is HOLD or CONFIRMED';

