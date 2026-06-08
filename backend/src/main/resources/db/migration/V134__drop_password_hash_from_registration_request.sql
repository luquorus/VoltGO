-- Drop password_hash column from collaborator_registration_request
-- Password is already stored in user_account at registration time.
-- The registration request only collects profile/banking info for admin review.
ALTER TABLE collaborator_registration_request
    DROP COLUMN IF EXISTS password_hash;
