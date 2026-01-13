package com.example.evstation.verification.api.dto;

import com.example.evstation.verification.domain.VerificationTaskStatus;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;

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
    
    // Nested details
    private CheckinDTO checkin;
    private ReviewDTO review;
    
    @Data
    @Builder
    public static class CheckinDTO {
        private Double lat;
        private Double lng;
        private Instant checkedInAt;
        private Integer distanceM;
        private String deviceNote;
    }
    
    @Data
    @Builder
    public static class ReviewDTO {
        private String result;
        private String adminNote;
        private Instant reviewedAt;
        private String reviewedBy;
    }
}

