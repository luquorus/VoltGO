package com.example.evstation.api.ev_user_mobile.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class RecommendationRequestDTO {
    
    @NotNull(message = "Current location is required")
    @Valid
    private LocationDTO currentLocation;
    
    @NotNull(message = "Radius is required")
    @Positive(message = "Radius must be positive")
    private Double radiusKm;
    
    @NotNull(message = "Battery percent is required")
    @Min(value = 0, message = "Battery percent must be >= 0")
    @Max(value = 100, message = "Battery percent must be <= 100")
    private Integer batteryPercent;
    
    @NotNull(message = "Battery capacity is required")
    @Positive(message = "Battery capacity must be positive")
    private Double batteryCapacityKwh;
    
    @Min(value = 0, message = "Target percent must be >= 0")
    @Max(value = 100, message = "Target percent must be <= 100")
    private Integer targetPercent; // default 80
    
    private Double consumptionKwhPerKm; // default 0.18
    private Double averageSpeedKmph; // default 30
    private Double vehicleMaxChargeKw; // default 120
    private Integer limit; // default 10
    
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
}

