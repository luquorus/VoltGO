package com.example.evstation.api.ev_user_mobile.dto;

import com.example.evstation.station.domain.*;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class ChangeRequestResponseDTO {
    private UUID id;
    private ChangeRequestType type;
    private ChangeRequestStatus status;
    private UUID stationId;
    private UUID proposedStationVersionId;
    private UUID submittedBy;
    private Integer riskScore;
    private List<String> riskReasons;
    private String adminNote;
    private Instant createdAt;
    private Instant submittedAt;
    private Instant decidedAt;
    
    /**
     * List of MinIO object keys for uploaded images.
     * Use /api/ev/files/presign-view?objectKey={key} to get view URLs.
     */
    private List<String> imageUrls;
    
    // Embedded station data for convenience
    private StationDataDTO stationData;
    
    @Data
    @Builder
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
    public static class ServiceDTO {
        private ServiceType type;
        private List<ChargingPortDTO> chargingPorts;
    }
    
    @Data
    @Builder
    public static class ChargingPortDTO {
        private PowerType powerType;
        private BigDecimal powerKw;
        private Integer count;
    }
}

