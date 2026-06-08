package com.example.evstation.risk.domain;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * Enumeration of battery swap specific risk reason codes.
 * Based on design doc section 4.2 risk assessment categories.
 */
@Getter
@RequiredArgsConstructor
public enum BatterySwapRiskReason {

    // Location Risks (Section 4.2.1)
    /**
     * Station is in a new/proposed location not verified.
     */
    NEW_BATTERY_SWAP_STATION("New battery swap station location", 15),

    /**
     * Station location has changed from previous.
     */
    LOCATION_CHANGED("Station location changed", 30),

    /**
     * Station location differs significantly from declared address.
     */
    GPS_MISMATCH("GPS location mismatch with declared address", 40),

    /**
     * Station is in a sensitive/restricted area.
     */
    SENSITIVE_AREA("Station in sensitive or restricted area", 25),

    // Data Accuracy Risks (Section 4.2.2)
    /**
     * Total battery count differs significantly from previous.
     */
    BATTERY_COUNT_CHANGED("Total battery count changed significantly", 20),

    /**
     * Average charge power differs significantly from previous.
     */
    CHARGE_POWER_CHANGED("Average charge power changed significantly", 20),

    /**
     * Pile/slot configuration differs from previous.
     */
    PILE_CONFIG_CHANGED("Pile or slot configuration changed", 25),

    /**
     * Operating hours differs from previous.
     */
    OPERATING_HOURS_CHANGED("Operating hours changed", 10),

    /**
     * Parking fee differs from previous.
     */
    PARKING_FEE_CHANGED("Parking fee changed", 10),

    // Operation Risks (Section 4.2.3)
    /**
     * Battery inventory is low (below threshold).
     */
    LOW_BATTERY_INVENTORY("Low battery inventory", 30),

    /**
     * Average charge power is outside normal range.
     */
    ABNORMAL_CHARGE_POWER("Average charge power outside normal range (10-200 kW)", 25),

    /**
     * Operating hours suggest limited availability.
     */
    LIMITED_AVAILABILITY("Limited operating hours may affect availability", 15),

    /**
     * Configuration indicates potential service issues.
     */
    CONFIGURATION_ISSUE("Potential configuration issue detected", 20),

    // Financial Risks (Section 4.2.4)
    /**
     * Significant price/fee changes detected.
     */
    PRICE_SIGNIFICANTLY_CHANGED("Significant price change detected", 20),

    /**
     * Pricing information incomplete or missing.
     */
    MISSING_PRICE_INFO("Pricing information incomplete or missing", 15),

    /**
     * Pricing differs from market average.
     */
    PRICE_DEVIATION("Price significantly deviates from market average", 20),

    // Safety Risks (Section 4.2.5)
    /**
     * Station may not meet safety standards.
     */
    SAFETY_CONCERN("Potential safety concern identified", 35),

    /**
     * Required safety equipment missing.
     */
    MISSING_SAFETY_EQUIPMENT("Required safety equipment missing", 30),

    /**
     * Environmental conditions may affect safety.
     */
    ENVIRONMENTAL_RISK("Environmental conditions may affect safety", 25),

    // Provider Trust Risks (Section 4.2.6)
    /**
     * Provider has low trust score.
     */
    LOW_TRUST_PROVIDER("Provider has low trust score", 25),

    /**
     * Provider has high change request rejection rate.
     */
    HIGH_REJECTION_RATE("Provider has high change request rejection rate", 20),

    /**
     * Provider has pending verification tasks.
     */
    PENDING_VERIFICATIONS("Provider has pending verification tasks", 15),

    /**
     * Provider is new (limited history).
     */
    NEW_PROVIDER("Provider is new with limited verification history", 20);

    private final String description;
    private final int scoreContribution;
}
