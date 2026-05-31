-- V119: Redesigned battery swap system
-- New tables: swap_payment, swap_session, charging_session, battery_event
-- New fields on battery_swap_reservation: swap_code, swap_deadline_at
-- Changes to battery_slot: battery_serial_number

-- =====================================================================
-- 1. swap_payment table — tracks payment lifecycle per reservation
-- =====================================================================
CREATE TABLE swap_payment (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id  UUID NOT NULL REFERENCES battery_swap_reservation(id) ON DELETE CASCADE,
    amount_vnd      BIGINT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'PENDING',
    -- status: PENDING | SUCCESS | FAILED | REFUNDED | EXPIRED
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    paid_at         TIMESTAMP,
    refunded_at     TIMESTAMP,
    expired_at      TIMESTAMP,
    CONSTRAINT ck_swap_payment_status CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'REFUNDED', 'EXPIRED'))
);

CREATE INDEX idx_swap_payment_reservation_id ON swap_payment(reservation_id);
CREATE INDEX idx_swap_payment_status ON swap_payment(status);

-- =====================================================================
-- 2. swap_session table — tracks the physical swap event with code
-- =====================================================================
CREATE TABLE swap_session (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reservation_id  UUID NOT NULL REFERENCES battery_swap_reservation(id) ON DELETE CASCADE,
    swap_code       TEXT NOT NULL UNIQUE,
    -- status: PENDING | COMPLETED | EXPIRED | CANCELLED
    status          TEXT NOT NULL DEFAULT 'PENDING',
    expires_at      TIMESTAMP NOT NULL,
    started_at      TIMESTAMP,
    completed_at    TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by      UUID,
    completed_by    UUID,
    CONSTRAINT ck_swap_session_status CHECK (status IN ('PENDING', 'COMPLETED', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT ck_swap_code_length CHECK (char_length(swap_code) >= 4)
);

CREATE INDEX idx_swap_session_reservation_id ON swap_session(reservation_id);
CREATE INDEX idx_swap_session_swap_code ON swap_session(swap_code);
CREATE INDEX idx_swap_session_status ON swap_session(status);
CREATE INDEX idx_swap_session_expires_at ON swap_session(expires_at);

-- =====================================================================
-- 3. charging_session table — tracks battery charging lifecycle
-- =====================================================================
CREATE TABLE charging_session (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    battery_slot_id UUID NOT NULL REFERENCES battery_slot(id) ON DELETE CASCADE,
    start_percent   INTEGER NOT NULL DEFAULT 0,
    end_percent     INTEGER,
    start_kwh      NUMERIC(8,4),
    end_kwh        NUMERIC(8,4),
    -- status: CHARGING | COMPLETED | CANCELLED
    status          TEXT NOT NULL DEFAULT 'CHARGING',
    started_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    estimated_full_at TIMESTAMP,
    completed_at    TIMESTAMP,
    CONSTRAINT ck_charging_session_percent_start CHECK (start_percent >= 0 AND start_percent <= 100),
    CONSTRAINT ck_charging_session_percent_end CHECK (end_percent IS NULL OR (end_percent >= 0 AND end_percent <= 100)),
    CONSTRAINT ck_charging_session_status CHECK (status IN ('CHARGING', 'COMPLETED', 'CANCELLED'))
);

CREATE INDEX idx_charging_session_slot_id ON charging_session(battery_slot_id);
CREATE INDEX idx_charging_session_status ON charging_session(status);
CREATE INDEX idx_charging_session_started_at ON charging_session(started_at);

-- =====================================================================
-- 4. battery_event table — event sourcing / audit log for batteries
-- =====================================================================
CREATE TABLE battery_event (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    battery_slot_id UUID NOT NULL REFERENCES battery_slot(id) ON DELETE CASCADE,
    event_type    TEXT NOT NULL,
    -- event_type: BATTERY_INSERTED | BATTERY_REMOVED | CHARGING_STARTED | CHARGING_COMPLETED |
    --             RESERVED | UNRESERVED | SWAPPED_IN | SWAPPED_OUT | STATUS_CHANGED | FULLY_CHARGED
    old_state     TEXT,
    new_state     TEXT,
    old_percent   INTEGER,
    new_percent   INTEGER,
    metadata      JSONB,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by    UUID,
    actor_type    TEXT
    -- actor_type: USER | ADMIN | SIMULATOR | SYSTEM
);

CREATE INDEX idx_battery_event_slot_id ON battery_event(battery_slot_id);
CREATE INDEX idx_battery_event_type ON battery_event(event_type);
CREATE INDEX idx_battery_event_created_at ON battery_event(created_at DESC);

-- =====================================================================
-- 5. Add new columns to battery_swap_reservation
-- =====================================================================
ALTER TABLE battery_swap_reservation
    ADD COLUMN IF NOT EXISTS swap_code TEXT;

ALTER TABLE battery_swap_reservation
    ADD COLUMN IF NOT EXISTS swap_deadline_at TIMESTAMP;

-- swap_deadline_at = appointment_time + 15 minutes
-- swap_code is generated by admin/system when user is in valid window

CREATE INDEX IF NOT EXISTS idx_swap_reservation_swap_code ON battery_swap_reservation(swap_code);

-- =====================================================================
-- 6. Add battery serial number to battery_slot
-- =====================================================================
ALTER TABLE battery_slot
    ADD COLUMN IF NOT EXISTS battery_serial_number TEXT;

ALTER TABLE battery_slot
    ADD COLUMN IF NOT EXISTS battery_capacity_kwh NUMERIC(6,2) DEFAULT 60.00;

-- =====================================================================
-- 7. Backfill swap_payment for existing reservations (UNPAID → PENDING, PAID → SUCCESS)
-- =====================================================================
INSERT INTO swap_payment (id, reservation_id, amount_vnd, status, created_at, paid_at)
SELECT
    gen_random_uuid(),
    r.id,
    r.base_price_vnd,
    CASE r.payment_status
        WHEN 'PAID' THEN 'SUCCESS'
        WHEN 'REFUNDED' THEN 'REFUNDED'
        ELSE 'PENDING'
    END,
    r.reserved_at,
    CASE WHEN r.payment_status = 'PAID' THEN r.reserved_at ELSE NULL END
FROM battery_swap_reservation r
WHERE r.payment_status IN ('PAID', 'REFUNDED')
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 8. Drop old estimated_ready_at if it conflicts with new flow
--    (We keep it — it was used for old COMPLETED flow. New flow uses charging_session.)
-- =====================================================================
