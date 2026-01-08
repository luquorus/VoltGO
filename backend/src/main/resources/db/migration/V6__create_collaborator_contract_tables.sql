-- Collaborator profile and contract management tables

-- Create contract status enum
CREATE TYPE contract_status AS ENUM ('ACTIVE', 'TERMINATED');

-- 1. collaborator_profile table
CREATE TABLE collaborator_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_account_id UUID NOT NULL UNIQUE REFERENCES user_account(id) ON DELETE CASCADE,
    full_name TEXT,
    phone TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_collaborator_profile_user_account_id ON collaborator_profile(user_account_id);

-- 2. contract table
CREATE TABLE contract (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collaborator_id UUID NOT NULL REFERENCES collaborator_profile(id) ON DELETE CASCADE,
    region TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status contract_status NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    terminated_at TIMESTAMP,
    note TEXT,
    
    -- Check constraints
    CONSTRAINT ck_contract_end_date_after_start CHECK (end_date >= start_date),
    CONSTRAINT ck_contract_terminated_at_when_terminated 
        CHECK ((status = 'TERMINATED' AND terminated_at IS NOT NULL) 
               OR (status = 'ACTIVE' AND terminated_at IS NULL))
);

CREATE INDEX idx_contract_collaborator_id ON contract(collaborator_id);
CREATE INDEX idx_contract_status ON contract(status);
CREATE INDEX idx_contract_dates ON contract(start_date, end_date);

-- Comments for documentation
COMMENT ON TABLE collaborator_profile IS 'Profile information for collaborators who verify stations';
COMMENT ON TABLE contract IS 'Contracts defining when collaborators can submit verification evidence';
COMMENT ON COLUMN contract.region IS 'Optional region assignment for auto-assign feature';
COMMENT ON COLUMN contract.status IS 'ACTIVE: contract valid, TERMINATED: contract ended early';

