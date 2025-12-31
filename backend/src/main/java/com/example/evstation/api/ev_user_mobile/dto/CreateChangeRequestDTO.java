package com.example.evstation.api.ev_user_mobile.dto;

import com.example.evstation.station.domain.ChangeRequestType;
import com.example.evstation.station.domain.ParkingType;
import com.example.evstation.station.domain.PowerType;
import com.example.evstation.station.domain.PublicStatus;
import com.example.evstation.station.domain.ServiceType;
import com.example.evstation.station.domain.VisibilityType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Data
public class CreateChangeRequestDTO {
    
    @NotNull(message = "Type is required")
    private ChangeRequestType type;
    
    // Required for UPDATE_STATION, must be null for CREATE_STATION
    private UUID stationId;
    
    @NotNull(message = "Station data is required")
    @Valid
    private StationDataDTO stationData;
    
    @Data
    public static class StationDataDTO {
        @NotBlank(message = "Name is required")
        @Size(min = 3, max = 255, message = "Name must be between 3 and 255 characters")
        private String name;
        
        @NotBlank(message = "Address is required")
        private String address;
        
        @NotNull(message = "Location is required")
        @Valid
        private LocationDTO location;
        
        private String operatingHours;
        
        @NotNull(message = "Parking type is required")
        private ParkingType parking;
        
        @NotNull(message = "Visibility is required")
        private VisibilityType visibility;
        
        @NotNull(message = "Public status is required")
        private PublicStatus publicStatus;
        
        @NotEmpty(message = "At least one service is required")
        @Valid
        private List<ServiceDTO> services;
    }
    
    @Data
    public static class LocationDTO {
        @NotNull(message = "Latitude is required")
        @DecimalMin(value = "-90", message = "Latitude must be >= -90")
        @DecimalMax(value = "90", message = "Latitude must be <= 90")
        private Double lat;
        
        @NotNull(message = "Longitude is required")
        @DecimalMin(value = "-180", message = "Longitude must be >= -180")
        @DecimalMax(value = "180", message = "Longitude must be <= 180")
        private Double lng;
    }
    
    @Data
    public static class ServiceDTO {
        @NotNull(message = "Service type is required")
        private ServiceType type;
        
        // Required if type is CHARGING
        @Valid
        private List<ChargingPortDTO> chargingPorts;
    }
    
    @Data
    public static class ChargingPortDTO {
        @NotNull(message = "Power type is required")
        private PowerType powerType;
        
        // Required for DC, optional for AC
        private BigDecimal powerKw;
        
        @NotNull(message = "Port count is required")
        @Min(value = 1, message = "Port count must be at least 1")
        private Integer count;
    }
}

