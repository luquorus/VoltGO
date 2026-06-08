package com.example.evstation.batteryswap.api.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

/**
 * Admin DTO for listing battery swap stations.
 */
@Data
@Builder
public class BatterySwapStationListDTO {

    // Station core
    private String id;
    private String providerId;
    private String providerEmail;
    private Instant stationCreatedAt;

    // Published version info (from station_version join)
    private String publishedVersionId;
    private Integer publishedVersionNo;
    private String name;
    private String address;
    private Double lat;
    private Double lng;
    private String operatingHours;
    private String workflowStatus;
    private String publicStatus;
    private Instant publishedAt;
    private String createdBy;
    private String createdByEmail;

    // Battery swap specific
    private Integer totalBatteries;
    private Integer availableBatteries;
    private BigDecimal avgChargePowerKw;
    private BigDecimal basePriceVnd;
    private Integer totalPiles;
    private Integer totalSlots;
    private Integer availableSlots;
    private String parkingFee;

    // Trust
    private Integer trustScore;
    private String trustLevel;

    // Stats
    private Integer totalVersions;
    private Integer pendingCRs;
}
