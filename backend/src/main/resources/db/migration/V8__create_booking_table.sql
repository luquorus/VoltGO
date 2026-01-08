-- Booking table for EV Users to book charging slots

-- Create enum type for booking status
CREATE TYPE booking_status AS ENUM (
    'HOLD',
    'CONFIRMED',
    'CANCELLED',
    'EXPIRED'
);

-- Create booking table
CREATE TABLE booking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    status booking_status NOT NULL DEFAULT 'HOLD',
    hold_expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Check constraints
    CONSTRAINT ck_booking_end_after_start CHECK (end_time > start_time),
    CONSTRAINT ck_booking_hold_expires_after_created 
        CHECK (hold_expires_at > created_at),
    CONSTRAINT ck_booking_hold_expires_when_hold 
        CHECK ((status = 'HOLD' AND hold_expires_at IS NOT NULL) 
               OR (status != 'HOLD'))
);

-- Create indexes as specified
CREATE INDEX idx_booking_user_id ON booking(user_id);
CREATE INDEX idx_booking_station_id ON booking(station_id);
CREATE INDEX idx_booking_status ON booking(status);
CREATE INDEX idx_booking_hold_expires_at ON booking(hold_expires_at) 
    WHERE status = 'HOLD';

-- Additional useful indexes
CREATE INDEX idx_booking_created_at ON booking(created_at DESC);
CREATE INDEX idx_booking_start_time ON booking(start_time);
CREATE INDEX idx_booking_user_status ON booking(user_id, status);

-- Comments
COMMENT ON TABLE booking IS 'Bookings made by EV users for charging slots at stations';
COMMENT ON COLUMN booking.status IS 'HOLD (waiting payment), CONFIRMED (paid), CANCELLED (user cancelled), EXPIRED (hold expired)';
COMMENT ON COLUMN booking.hold_expires_at IS 'When the HOLD status expires (10 minutes after creation)';
COMMENT ON INDEX idx_booking_hold_expires_at IS 'Partial index for efficient query of expired HOLD bookings';

