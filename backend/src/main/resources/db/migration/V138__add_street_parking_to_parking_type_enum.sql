-- V138: Add STREET_PARKING to parking_type PostgreSQL enum.
--
-- Allows admin to specify parking = STREET_PARKING when creating a battery swap
-- (or any other) station. The Java enum ParkingType was updated to include this
-- value (parking_type.PAID, FREE, STREET_PARKING, UNKNOWN).
--
-- Note: ALTER TYPE ... ADD VALUE cannot run inside a transaction block, so
-- Flyway will run it as a single auto-commit statement. Existing rows are
-- unaffected (this only adds a new enum label).

ALTER TYPE parking_type ADD VALUE IF NOT EXISTS 'STREET_PARKING';
