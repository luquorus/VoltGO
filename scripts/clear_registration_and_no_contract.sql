-- =============================================================================
-- VoltGo Database Cleanup: Registration Requests + Collaborators without Contracts
-- =============================================================================
-- Run this script connected to the voltgo database.
-- E.g. via psql:  psql -h localhost -U voltgo_user -d voltgo -f clear_registration_and_no_contract.sql
-- =============================================================================

-- Step 1: Delete all collaborator registration requests
-- (No foreign key dependencies, safe to delete directly)
DELETE FROM collaborator_registration_request;
-- Row count: rows deleted from registration requests

-- Step 2: Find collaborators WITHOUT any contracts
-- These are profiles that either:
--   a) Have no contracts at all (never had one), OR
--   b) Have only TERMINATED contracts (current contract status = terminated)
WITH no_active_contract AS (
    SELECT cp.id AS collaborator_profile_id, cp.user_account_id
    FROM collaborator_profile cp
    LEFT JOIN contract c ON c.collaborator_id = cp.id
    GROUP BY cp.id, cp.user_account_id
    HAVING COUNT(c.id) = 0
       OR (COUNT(c.id) > 0 AND BOOL_AND(c.status = 'TERMINATED'))
)
-- Step 3: Delete user accounts for those collaborators
-- Cascade: user_account ON DELETE CASCADE will automatically delete collaborator_profile and contract
DELETE FROM user_account
WHERE id IN (SELECT user_account_id FROM no_active_contract);
-- Row count: rows deleted from user_account (cascades to collaborator_profile and contract)

-- =============================================================================
-- Summary: After running this script:
--   - All registration requests are gone
--   - Collaborators without active contracts are gone (profile + user account)
--   - Collaborators WITH active contracts are preserved
-- =============================================================================
