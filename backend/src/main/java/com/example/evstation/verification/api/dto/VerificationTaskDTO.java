package com.example.evstation.verification.api.dto;

import com.example.evstation.verification.domain.VerificationTaskStatus;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;

@Data
@Builder
public class VerificationTaskDTO {
    private String id;
    private String stationId;
    private String stationName;
    private String changeRequestId;
    private Integer priority;
    private Instant slaDueAt;
    private String assignedTo;
    private String assignedToEmail;
    private VerificationTaskStatus status;
    private Instant createdAt;
    private String verificationType;

    /** Service types on the station version under verification (e.g. CHARGING, BATTERY_SWAP). */
    private List<String> stationServiceTypes;

    /** Immutable checklist definition snapshot at task creation time. */
    private List<ChecklistItem> checklist;

    /** Station data snapshot at task creation time (expected values). */
    private StationSnapshotDTO stationSnapshot;

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
        private String note;
        private Instant submittedAt;
        private String submittedBy;
    }
}

