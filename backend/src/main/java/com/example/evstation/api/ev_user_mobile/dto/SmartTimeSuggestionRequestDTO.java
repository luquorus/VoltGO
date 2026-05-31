package com.example.evstation.api.ev_user_mobile.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class SmartTimeSuggestionRequestDTO {
    @NotNull
    private UUID stationId;

    @NotNull
    @Min(0)
    private Double distanceKm;

    @NotNull
    @Min(0)
    @Max(100)
    private Integer batteryPercent;

    @NotNull
    @Min(0)
    @Max(100)
    private Integer targetPercent;

    @NotNull
    @Min(1)
    private Double batteryCapacityKwh;

    @Min(5)
    private Double averageSpeedKmph;
}
