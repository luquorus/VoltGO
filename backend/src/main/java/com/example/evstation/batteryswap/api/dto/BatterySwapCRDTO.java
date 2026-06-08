package com.example.evstation.batteryswap.api.dto;

import com.example.evstation.batteryswap.domain.ChangeRequestStatus;
import com.example.evstation.batteryswap.domain.ChangeRequestType;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapChangeRequestEntity;
import com.example.evstation.station.domain.WorkflowStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Data
@Builder
public class BatterySwapCRDTO {

    // Change request fields
    private UUID id;
    private ChangeRequestType type;
    private ChangeRequestStatus status;
    private UUID stationId;
    private UUID submittedBy;
    private String submittedByEmail;
    private Integer riskScore;
    private List<String> riskReasons;
    private String adminNote;
    private Instant createdAt;
    private Instant submittedAt;
    private Instant decidedAt;

    // Station version fields
    private UUID versionId;
    private Integer versionNo;
    private WorkflowStatus workflowStatus;
    private Integer totalBatteries;
    private BigDecimal avgChargePowerKw;
    private String operatingHours;
    private BigDecimal parkingFee;
    private String note;
    private Instant publishedAt;

    // Pile/slot layout
    private List<PileDTO> pileTemplates;

    // Station name (for display)
    private String stationName;

    // Risk flags
    private Boolean requiresVerification;
    private Boolean requiresAdminReview;

    @Data
    @Builder
    public static class PileDTO {
        private UUID id;
        private Integer pileIndex;
        private Integer slotsPerPile;
        private List<SlotDTO> slots;
    }

    @Data
    @Builder
    public static class SlotDTO {
        private UUID id;
        private Integer slotIndex;
        private BigDecimal batteryCapacityKwh;
    }
}
