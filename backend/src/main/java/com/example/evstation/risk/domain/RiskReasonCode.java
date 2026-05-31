package com.example.evstation.risk.domain;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * Enumeration of risk reason codes for change request risk assessment.
 * Each code represents a specific type of change that contributes to the risk score.
 */
@Getter
@RequiredArgsConstructor
public enum RiskReasonCode {
    
    /**
     * GPS location changed by more than 100 meters.
     * High risk because location changes can indicate data quality issues or fraud.
     */
    GPS_CHANGED_100M("GPS location changed by more than 100m", 50),
    
    /**
     * Pricing information changed.
     * Moderate risk because price changes affect user experience.
     */
    PRICE_CHANGED("Pricing information changed", 20),
    
    /**
     * Charging ports configuration changed (power type, power kW, or count).
     * Moderate-high risk because port changes affect EV user charging plans.
     */
    PORTS_CHANGED("Charging ports configuration changed", 30),
    
    /**
     * Operating hours changed.
     * Low risk but important for user planning.
     */
    HOURS_CHANGED("Operating hours changed", 10),
    
    /**
     * Visibility or public status changed.
     * Low risk but affects station accessibility.
     */
    ACCESS_CHANGED("Visibility or public status changed", 10),
    
    /**
     * New station creation - baseline risk.
     * CREATE_STATION requests have inherent verification needs.
     */
    NEW_STATION("New station creation requires verification", 10),

    /**
     * Battery swap configuration changed (totalBatteries / avgChargePowerKw).
     * Moderate-high risk because it affects supply capacity at the station.
     */
    SWAP_CONFIG_CHANGED("Battery swap configuration changed", 30),

    /**
     * Battery swap inventory is too low (totalBatteries < 5).
     * High risk because supply is fragile; warrants verification.
     */
    SWAP_LOW_INVENTORY("Battery swap inventory is low (< 5)", 30),

    /**
     * Battery swap average charging power is outside normal operating range (10-200 kW).
     */
    SWAP_AVG_POWER_OUT_OF_RANGE("Battery swap avg power out of range", 20);

    private final String description;
    private final int scoreContribution;
}

