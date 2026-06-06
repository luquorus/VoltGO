-- Collaborator Registration Request table
-- Stores self-registration requests from collab mobile app

-- 1. collaborator_registration_request table
CREATE TABLE collaborator_registration_request (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    address TEXT,
    id_card_number VARCHAR(20),
    bank_account_number VARCHAR(50),
    bank_name VARCHAR(100),
    referral_code VARCHAR(50),
    contract_agreed_at TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    rejection_reason TEXT,
    submission_count INTEGER NOT NULL DEFAULT 1,
    reviewed_by UUID,
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add constraint for status enum
ALTER TABLE collaborator_registration_request
    ADD CONSTRAINT chk_registration_request_status
    CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'));

-- Indexes for common queries
CREATE INDEX idx_reg_req_email ON collaborator_registration_request(email);
CREATE INDEX idx_reg_req_status ON collaborator_registration_request(status);
CREATE INDEX idx_reg_req_created_at ON collaborator_registration_request(created_at);
CREATE INDEX idx_reg_req_email_status ON collaborator_registration_request(email, status);
