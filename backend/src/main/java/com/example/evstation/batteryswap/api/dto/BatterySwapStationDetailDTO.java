package com.example.evstation.batteryswap.api.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

/**
 * Admin DTO for battery swap station detail view (with pile layout).
 */
@Data
@Builder
public class BatterySwapStationDetailDTO {

    // Station core
    private String id;
    private String providerId;
    private String providerEmail;
    private Instant stationCreatedAt;

    // Published version info
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

    // Full pile layout (from published version)
    private List<PileTemplateDTO> pileTemplates;

    // Note
    private String note;

    @Data
    @Builder
    public static class PileTemplateDTO {
        private String id;
        private Integer pileIndex;
        private Integer slotsPerPile;
        private List<SlotTemplateDTO> slots;
    }

    @Data
    @Builder
    public static class SlotTemplateDTO {
        private String id;
        private Integer slotIndex;
        private BigDecimal batteryCapacityKwh;
    }
}
