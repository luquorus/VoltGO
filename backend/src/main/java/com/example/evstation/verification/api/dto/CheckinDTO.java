package com.example.evstation.verification.api.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CheckinDTO {
    @NotNull(message = "Latitude is required")
    @DecimalMin(value = "-90", message = "Latitude must be >= -90")
    @DecimalMax(value = "90", message = "Latitude must be <= 90")
    private Double lat;
    
    @NotNull(message = "Longitude is required")
    @DecimalMin(value = "-180", message = "Longitude must be >= -180")
    @DecimalMax(value = "180", message = "Longitude must be <= 180")
    private Double lng;
    
    private String deviceNote;
}

