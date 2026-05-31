-- V112: Create swap_pile and battery_slot tables
-- These tables are needed for V111 seed data

-- =====================================================================
-- 1. swap_pile table
-- =====================================================================
CREATE TABLE swap_pile (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id      UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    pile_index      INTEGER NOT NULL,
    status          TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_swap_pile_station_index UNIQUE (station_id, pile_index),
    CONSTRAINT ck_swap_pile_status CHECK (status IN ('ACTIVE', 'MAINTENANCE'))
);

CREATE INDEX idx_swap_pile_station_id ON swap_pile(station_id);

-- =====================================================================
-- 2. battery_slot table
-- =====================================================================
CREATE TABLE battery_slot (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pile_id                UUID NOT NULL REFERENCES swap_pile(id) ON DELETE CASCADE,
    slot_index             INTEGER NOT NULL,
    battery_id             UUID,
    battery_charge_percent INTEGER NOT NULL DEFAULT 100,
    status                 TEXT NOT NULL DEFAULT 'AVAILABLE',
    charging_started_at    TIMESTAMP,
    updated_at             TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_battery_slot_pile_index UNIQUE (pile_id, slot_index),
    CONSTRAINT ck_battery_slot_status CHECK (status IN ('AVAILABLE', 'OCCUPIED', 'CHARGING', 'RESERVED', 'SWAPPED_OUT')),
    CONSTRAINT ck_battery_slot_percent CHECK (battery_charge_percent >= 0 AND battery_charge_percent <= 100)
);

CREATE INDEX idx_battery_slot_pile_id ON battery_slot(pile_id);
CREATE INDEX idx_battery_slot_status ON battery_slot(status);

-- =====================================================================
-- 3. Add pile_id and slot_id to reservation (if not exists)
-- =====================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'battery_swap_reservation' AND column_name = 'pile_id'
    ) THEN
        ALTER TABLE battery_swap_reservation
            ADD COLUMN pile_id UUID REFERENCES swap_pile(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'battery_swap_reservation' AND column_name = 'slot_id'
    ) THEN
        ALTER TABLE battery_swap_reservation
            ADD COLUMN slot_id UUID REFERENCES battery_slot(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_battery_swap_reservation_pile_id ON battery_swap_reservation(pile_id);
CREATE INDEX IF NOT EXISTS idx_battery_swap_reservation_slot_id ON battery_swap_reservation(slot_id);
