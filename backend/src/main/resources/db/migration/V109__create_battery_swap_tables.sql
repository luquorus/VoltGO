CREATE TABLE battery_swap_station_state (
    station_id UUID PRIMARY KEY REFERENCES station(id) ON DELETE CASCADE,
    total_batteries INTEGER NOT NULL DEFAULT 20,
    available_batteries INTEGER NOT NULL DEFAULT 10,
    avg_charge_power_kw NUMERIC(8,2) NOT NULL DEFAULT 35.0,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_battery_swap_total_positive CHECK (total_batteries > 0),
    CONSTRAINT ck_battery_swap_available_non_negative CHECK (available_batteries >= 0),
    CONSTRAINT ck_battery_swap_available_le_total CHECK (available_batteries <= total_batteries)
);

CREATE INDEX idx_battery_swap_station_state_updated_at ON battery_swap_station_state(updated_at DESC);

CREATE TABLE battery_swap_reservation (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE,
    station_id UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    reserved_slot_at TIMESTAMP,
    requested_battery_percent INTEGER NOT NULL DEFAULT 20,
    target_battery_percent INTEGER NOT NULL DEFAULT 90,
    battery_capacity_kwh NUMERIC(8,2) NOT NULL DEFAULT 60.0,
    estimated_ready_at TIMESTAMP,
    note TEXT,
    reserved_at TIMESTAMP NOT NULL DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_battery_swap_status CHECK (status IN ('RESERVED', 'SWAPPING', 'COMPLETED', 'CANCELLED', 'EXPIRED')),
    CONSTRAINT ck_battery_swap_percent_range CHECK (
        requested_battery_percent >= 0
        AND requested_battery_percent <= 100
        AND target_battery_percent >= 0
        AND target_battery_percent <= 100
        AND target_battery_percent >= requested_battery_percent
    ),
    CONSTRAINT ck_battery_swap_capacity_positive CHECK (battery_capacity_kwh > 0)
);

CREATE INDEX idx_battery_swap_reservation_user_id ON battery_swap_reservation(user_id);
CREATE INDEX idx_battery_swap_reservation_station_id ON battery_swap_reservation(station_id);
CREATE INDEX idx_battery_swap_reservation_status ON battery_swap_reservation(status);
CREATE INDEX idx_battery_swap_reservation_reserved_at ON battery_swap_reservation(reserved_at DESC);

INSERT INTO battery_swap_station_state (station_id, total_batteries, available_batteries, avg_charge_power_kw)
SELECT DISTINCT sv.station_id, 20, 10, 35.0
FROM station_version sv
JOIN station_service ss ON ss.station_version_id = sv.id
WHERE sv.workflow_status = 'PUBLISHED'
  AND ss.service_type = 'BATTERY_SWAP'
ON CONFLICT (station_id) DO NOTHING;
