package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class RouteSummaryDTO {
    private double distanceKm;
    private int durationMinutes;
    private boolean viaRoad;
    private boolean hasChargingStations;
    private Boolean needsChargingRecommendation;
    private String primaryRecommendationReason;
}
