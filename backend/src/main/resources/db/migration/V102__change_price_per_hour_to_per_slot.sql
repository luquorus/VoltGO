-- Change price_per_hour to price_per_slot (30 minutes per slot)
-- Convert existing prices: price_per_slot = price_per_hour / 2 (rounded)
-- This makes pricing consistent with 30-minute slot duration

-- Step 1: Add new column price_per_slot
ALTER TABLE charger_unit 
    ADD COLUMN price_per_slot INTEGER;

-- Step 2: Convert existing prices (divide by 2, round)
-- Example: 20000 VND/hour -> 10000 VND/slot (30 minutes)
UPDATE charger_unit 
SET price_per_slot = ROUND(price_per_hour::NUMERIC / 2)::INTEGER;

-- Step 3: Make price_per_slot NOT NULL and add constraint
ALTER TABLE charger_unit 
    ALTER COLUMN price_per_slot SET NOT NULL,
    ADD CONSTRAINT ck_charger_unit_price_per_slot_positive 
        CHECK (price_per_slot >= 0);

-- Step 4: Drop old column and constraint
ALTER TABLE charger_unit 
    DROP COLUMN price_per_hour;

-- Step 5: Update comments
COMMENT ON COLUMN charger_unit.price_per_slot IS 'Price in VND per slot (30 minutes)';

-- Step 6: Update price_snapshot in booking table
-- Change pricePerHour -> pricePerSlot in JSON snapshots
UPDATE booking
SET price_snapshot = jsonb_set(
    price_snapshot,
    '{pricePerSlot}',
    to_jsonb((price_snapshot->>'pricePerHour')::INTEGER / 2)
) - 'pricePerHour';

-- Step 7: Update comment for price_snapshot
COMMENT ON COLUMN booking.price_snapshot IS 'JSON snapshot of pricing at booking time: {unitLabel, powerType, powerKw, pricePerSlot, durationMinutes, slotCount, amount}';

