-- V137: Remove dummy ChargingPort rows that were auto-created for Battery Swap stations.
--
-- Battery swap stations do not have real charging ports. Previously,
-- BatterySwapStationAdminService.createSwapStationServiceAndPort() created a synthetic
-- DC ChargingPortEntity for every swap station so the EV user app could render a
-- non-empty "Charging ports" section. That dummy port incorrectly caused the EV user
-- app to also show the "Book charging slot" button, which then failed at booking time.
--
-- This migration deletes any charging_port rows whose station_service is BATTERY_SWAP.
-- It is safe to run repeatedly — once the rows are removed, the DELETE matches nothing.

DELETE FROM charging_port
WHERE station_service_id IN (
    SELECT ss.id
    FROM station_service ss
    WHERE ss.service_type = 'BATTERY_SWAP'
);
