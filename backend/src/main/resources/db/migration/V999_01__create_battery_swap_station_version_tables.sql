-- ============================================================
-- V999_01__create_battery_swap_station_version_tables.sql
-- Creates tables for battery swap station version management
-- ============================================================

-- Battery Swap Station Version - manages versions of battery swap station configurations
CREATE TABLE battery_swap_station_version (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id          UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    version_no          INTEGER NOT NULL DEFAULT 1,
    workflow_status     VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    total_batteries     INTEGER NOT NULL,
    avg_charge_power_kw DECIMAL(6,2) NOT NULL,
    operating_hours     VARCHAR(100) NOT NULL,
    parking_fee         DECIMAL(10,2),
    note                TEXT,
    created_by          UUID NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    published_at        TIMESTAMP WITH TIME ZONE,
    submitted_at        TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uk_bsv_station_version UNIQUE (station_id, version_no)
);

CREATE INDEX idx_bsv_station ON battery_swap_station_version(station_id);
CREATE INDEX idx_bsv_workflow ON battery_swap_station_version(workflow_status);

-- Battery Swap Pile Template - template for swap pile configuration
CREATE TABLE battery_swap_pile_template (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_version_id  UUID NOT NULL REFERENCES battery_swap_station_version(id) ON DELETE CASCADE,
    pile_index          INTEGER NOT NULL,
    slots_per_pile      INTEGER NOT NULL DEFAULT 6,
    CONSTRAINT uk_bpt_version_index UNIQUE (station_version_id, pile_index)
);

-- Battery Swap Slot Template - template for individual battery slots
CREATE TABLE battery_swap_slot_template (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pile_template_id    UUID NOT NULL REFERENCES battery_swap_pile_template(id) ON DELETE CASCADE,
    slot_index          INTEGER NOT NULL,
    battery_capacity_kwh DECIMAL(6,2) NOT NULL DEFAULT 60.0,
    CONSTRAINT uk_bslt_pile_slot UNIQUE (pile_template_id, slot_index)
);
