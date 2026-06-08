package com.example.evstation.verification.domain;

/**
 * Enumeration of evidence photo types for verification tasks.
 * Based on design doc section 6.4.
 */
public enum EvidencePhotoType {
    /**
     * Entrance/front of station.
     */
    STATION_ENTRANCE,

    /**
     * Charging equipment/charger units.
     */
    CHARGER_EQUIPMENT,

    /**
     * Payment/price information display.
     */
    PAYMENT_DISPLAY,

    /**
     * Operating hours sign.
     */
    OPERATING_HOURS_SIGN,

    /**
     * Battery swap pile/pile equipment.
     */
    BATTERY_SWAP_PILE,

    /**
     * Battery slot/inventory view.
     */
    BATTERY_SLOT,

    /**
     * Overall station overview.
     */
    STATION_OVERVIEW,

    /**
     * EV connector/charging port detail.
     */
    EV_CONNECTOR,

    /**
     * Street view showing station location.
     */
    STREET_VIEW,

    /**
     * Parking area/facility.
     */
    PARKING_AREA,

    /**
     * Safety equipment/fire extinguisher.
     */
    SAFETY_EQUIPMENT,

    /**
     * Additional/other evidence.
     */
    OTHER
}
