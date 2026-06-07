package com.example.evstation.verification.api.dto;

import com.example.evstation.verification.domain.VerificationTaskStatus;
import com.example.evstation.verification.domain.VerificationType;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;

/**
 * DTO for battery swap verification task with extended battery swap-specific fields.
 */
@Data
@Builder
public class BatterySwapVerificationTaskDTO {
    private String id;
    private String stationId;
    private String stationName;
    private String changeRequestId;
    private String batterySwapChangeRequestId;
    private Integer priority;
    private Instant slaDueAt;
    private String assignedTo;
    private String assignedToEmail;
    private VerificationTaskStatus status;
    private VerificationType verificationType;
    private Instant createdAt;

    // Battery swap specific snapshot data
    private Integer snapshotTotalBatteries;
    private Double snapshotAvgChargePowerKw;
    private Integer snapshotPileCount;
    private Integer snapshotSlotCount;
    private String snapshotOperatingHours;
    private Double snapshotParkingFee;

    // Station service types
    private List<String> stationServiceTypes;

    /** Immutable checklist definition snapshot at task creation time. */
    private List<ChecklistItem> checklist;

    // Nested details
    private CheckinDTO checkin;
    private List<EvidenceDTO> evidences;
    private ReviewDTO review;

    @Data
    @Builder
    public static class CheckinDTO {
        private Double lat;
        private Double lng;
        private Instant checkedInAt;
        private Integer distanceM;
        private String deviceNote;
        // Battery swap specific checkin fields
        private Integer actualTotalBatteries;
        private Integer actualAvailableBatteries;
        private Double observedAvgChargePowerKw;
        private List<ChecklistAnswer> checklistAnswers;
    }

    @Data
    @Builder
    public static class ReviewDTO {
        private String result;
        private String adminNote;
        private Instant reviewedAt;
        private String reviewedBy;
    }

    @Data
    @Builder
    public static class EvidenceDTO {
        private String id;
        private String photoObjectKey;
        private String photoType;
        private String note;
        private Instant submittedAt;
        private String submittedBy;
    }
}
