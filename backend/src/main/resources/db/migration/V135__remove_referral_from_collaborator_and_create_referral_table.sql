-- Remove referral_code from collaborator_registration_request (referral is now for EV_USER only)
ALTER TABLE collaborator_registration_request DROP COLUMN IF EXISTS referral_code;

-- Referral table: tracks referral codes and their status for EV_USER referrals
CREATE TABLE referral (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL,
    referee_id UUID,
    referral_code VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    referred_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_referral_code UNIQUE (referrer_id, referral_code)
);

-- Indexes
CREATE INDEX idx_referral_referrer ON referral(referrer_id);
CREATE INDEX idx_referral_referee ON referral(referee_id);
CREATE INDEX idx_referral_code ON referral(referral_code);
CREATE INDEX idx_referral_status ON referral(status);

-- Constraint for status enum
ALTER TABLE referral
    ADD CONSTRAINT chk_referral_status
    CHECK (status IN ('PENDING', 'REGISTERED', 'EARNED'));
