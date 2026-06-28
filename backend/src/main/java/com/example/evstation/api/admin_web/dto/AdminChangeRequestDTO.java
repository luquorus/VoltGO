package com.example.evstation.api.admin_web.dto;

import com.example.evstation.station.domain.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminChangeRequestDTO {
    private UUID id;
    private ChangeRequestType type;
    private ChangeRequestStatus status;
    private UUID stationId;
    private UUID proposedStationVersionId;
    private UUID submittedBy;
    private String submitterEmail;
    private Integer riskScore;
    private List<String> riskReasons;
    private String adminNote;
    private Instant createdAt;
    private Instant submittedAt;
    private Instant decidedAt;

    // Verification status (for high-risk CRs)
    private Boolean hasVerificationTask;
    private Boolean hasPassedVerification;

    // Station data
    private StationDataDTO stationData;

    // Audit history
    private List<AuditLogDTO> auditLogs;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StationDataDTO {
        private String name;
        private String address;
        private Double lat;
        private Double lng;
        private String operatingHours;
        private ParkingType parking;
        private VisibilityType visibility;
        private PublicStatus publicStatus;
        private List<ServiceDTO> services;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ServiceDTO {
        private ServiceType type;
        private List<ChargingPortDTO> chargingPorts;
        /** Present when type == BATTERY_SWAP */
        private Integer totalBatteries;
        /** Present when type == BATTERY_SWAP */
        private BigDecimal avgChargePowerKw;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChargingPortDTO {
        private PowerType powerType;
        private BigDecimal powerKw;
        private Integer count;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class AuditLogDTO {
        private String action;
        private UUID actorId;
        private String actorRole;
        private Instant createdAt;
        private Object metadata;
    }
}
