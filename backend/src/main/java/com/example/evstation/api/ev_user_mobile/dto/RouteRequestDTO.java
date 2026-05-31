package com.example.evstation.api.ev_user_mobile.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class RouteRequestDTO {
    
    @NotNull(message = "Origin is required")
    @Valid
    private LocationDTO origin;
    
    @NotNull(message = "Destination is required")
    @Valid
    private LocationDTO destination;
    
    @Min(value = 0, message = "Battery percent must be >= 0")
    @Max(value = 100, message = "Battery percent must be <= 100")
    private Integer batteryPercent;
    
    @Positive(message = "Battery capacity must be positive")
    private Double batteryCapacityKwh;
    
    @Min(value = 0, message = "Current charge percent must be >= 0")
    @Max(value = 100, message = "Current charge percent must be <= 100")
    private Integer currentChargePercent;
    
    @Positive(message = "Consumption must be positive")
    private Double consumptionKwhPerKm;
    
    @Positive(message = "Vehicle range must be positive")
    private Double vehicleRangeKm;
    
    @Min(value = 0, message = "Minimum power must be >= 0")
    private Double minPowerKw;
    
    @Min(value = 1, message = "Station limit must be at least 1")
    private Integer stationLimit;
    
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
