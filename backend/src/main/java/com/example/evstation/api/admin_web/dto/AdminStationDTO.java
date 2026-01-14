package com.example.evstation.api.admin_web.dto;

import com.example.evstation.station.domain.*;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class AdminStationDTO {
    private UUID stationId;
    private UUID providerId;
    private String providerEmail;
    private Instant stationCreatedAt;
    
    // Current published version info
    private UUID publishedVersionId;
    private Integer publishedVersionNo;
    private WorkflowStatus workflowStatus;
    private String name;
    private String address;
    private Double lat;
    private Double lng;
    private String operatingHours;
    private ParkingType parking;
    private VisibilityType visibility;
    private PublicStatus publicStatus;
    private Instant publishedAt;
    private UUID createdBy;
    private String createdByEmail;
    
    // Services and ports
    private List<ServiceDTO> services;
    
    // Trust score
    private Integer trustScore;
    
    // Statistics
    private Long totalVersions;
    private Long activeBookings;
    
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
        private Integer portCount;
    }
}

