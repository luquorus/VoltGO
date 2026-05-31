-- Station device keys for battery swap simulators/displays
CREATE TABLE battery_swap_station_device (
    station_id       UUID PRIMARY KEY REFERENCES battery_swap_station_state(station_id) ON DELETE CASCADE,
    device_key       VARCHAR(64)  NOT NULL UNIQUE,
    device_name      VARCHAR(100),
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_seen_at     TIMESTAMPTZ
);

CREATE INDEX idx_battery_swap_station_device_key ON battery_swap_station_device(device_key);
