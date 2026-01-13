-- Add name column to user_account table
ALTER TABLE user_account
ADD COLUMN name VARCHAR(255);

-- Update existing records to use email as default name
UPDATE user_account
SET name = email
WHERE name IS NULL;

-- Make name NOT NULL after setting defaults
ALTER TABLE user_account
ALTER COLUMN name SET NOT NULL;

COMMENT ON COLUMN user_account.name IS 'Display name for the user';

