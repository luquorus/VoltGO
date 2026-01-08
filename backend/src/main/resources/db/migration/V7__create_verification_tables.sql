-- Verification workflow tables

-- Create enums
CREATE TYPE verification_task_status AS ENUM ('OPEN', 'ASSIGNED', 'CHECKED_IN', 'SUBMITTED', 'REVIEWED');
CREATE TYPE verification_result AS ENUM ('PASS', 'FAIL');

-- 1. verification_task table
CREATE TABLE verification_task (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    station_id UUID NOT NULL REFERENCES station(id) ON DELETE CASCADE,
    change_request_id UUID REFERENCES change_request(id) ON DELETE SET NULL,
    priority INTEGER NOT NULL DEFAULT 3,
    sla_due_at TIMESTAMP,
    assigned_to UUID REFERENCES user_account(id) ON DELETE SET NULL,
    status verification_task_status NOT NULL DEFAULT 'OPEN',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Check constraints
    CONSTRAINT ck_verification_task_priority CHECK (priority >= 1 AND priority <= 5)
);

CREATE INDEX idx_verification_task_station_id ON verification_task(station_id);
CREATE INDEX idx_verification_task_change_request_id ON verification_task(change_request_id);
CREATE INDEX idx_verification_task_assigned_to ON verification_task(assigned_to);
CREATE INDEX idx_verification_task_status ON verification_task(status);
CREATE INDEX idx_verification_task_sla_due_at ON verification_task(sla_due_at);
CREATE INDEX idx_verification_task_priority ON verification_task(priority);

-- 2. verification_checkin table
CREATE TABLE verification_checkin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL UNIQUE REFERENCES verification_task(id) ON DELETE CASCADE,
    checkin_lat NUMERIC(10, 7) NOT NULL,
    checkin_lng NUMERIC(10, 7) NOT NULL,
    checked_in_at TIMESTAMP NOT NULL DEFAULT NOW(),
    distance_m INTEGER NOT NULL,
    device_note TEXT
);

CREATE INDEX idx_verification_checkin_task_id ON verification_checkin(task_id);

-- 3. verification_evidence table
CREATE TABLE verification_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES verification_task(id) ON DELETE CASCADE,
    photo_object_key TEXT NOT NULL,
    note TEXT,
    submitted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    submitted_by UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE
);

CREATE INDEX idx_verification_evidence_task_id ON verification_evidence(task_id);
CREATE INDEX idx_verification_evidence_submitted_by ON verification_evidence(submitted_by);

-- 4. verification_review table
CREATE TABLE verification_review (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL UNIQUE REFERENCES verification_task(id) ON DELETE CASCADE,
    result verification_result NOT NULL,
    admin_note TEXT,
    reviewed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    reviewed_by UUID NOT NULL REFERENCES user_account(id) ON DELETE CASCADE
);

CREATE INDEX idx_verification_review_task_id ON verification_review(task_id);
CREATE INDEX idx_verification_review_result ON verification_review(result);
CREATE INDEX idx_verification_review_reviewed_by ON verification_review(reviewed_by);

-- Comments
COMMENT ON TABLE verification_task IS 'Verification tasks for collaborators to verify station data';
COMMENT ON TABLE verification_checkin IS 'GPS check-in records for verification tasks';
COMMENT ON TABLE verification_evidence IS 'Photo evidence submitted by collaborators';
COMMENT ON TABLE verification_review IS 'Admin review results for verification tasks';
COMMENT ON COLUMN verification_task.priority IS 'Priority 1-5 (1=highest)';
COMMENT ON COLUMN verification_checkin.distance_m IS 'Distance in meters from station location at check-in';

