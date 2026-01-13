-- Add phone column to user_account table
ALTER TABLE user_account
ADD COLUMN phone VARCHAR(20);

COMMENT ON COLUMN user_account.phone IS 'Phone number for the user';

