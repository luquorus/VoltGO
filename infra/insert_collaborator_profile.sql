-- Insert collaborator profile for testcollab@voltgo.com
-- This script finds the user_account_id by email and inserts a profile if it doesn't exist

-- First, let's check if the user exists and get their ID
DO $$
DECLARE
    v_user_id UUID;
    v_profile_exists BOOLEAN;
BEGIN
    -- Find user account ID by email
    SELECT id INTO v_user_id
    FROM user_account
    WHERE email = 'testcollab@voltgo.com' AND role = 'COLLABORATOR';
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE 'User testcollab@voltgo.com not found or is not a COLLABORATOR';
        RETURN;
    END IF;
    
    -- Check if profile already exists
    SELECT EXISTS(
        SELECT 1 FROM collaborator_profile WHERE user_account_id = v_user_id
    ) INTO v_profile_exists;
    
    IF v_profile_exists THEN
        RAISE NOTICE 'Profile already exists for user: %', v_user_id;
        RETURN;
    END IF;
    
    -- Insert profile
    INSERT INTO collaborator_profile (id, user_account_id, full_name, phone, created_at)
    VALUES (
        gen_random_uuid(),
        v_user_id,
        'Test Collaborator',
        '+84123456789',
        NOW()
    );
    
    RAISE NOTICE 'Profile created successfully for user: %', v_user_id;
END $$;

