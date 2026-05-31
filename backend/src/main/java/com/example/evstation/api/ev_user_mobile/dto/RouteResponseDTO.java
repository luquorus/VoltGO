package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class RouteResponseDTO {
    private long distanceMeters;
    private long durationSeconds;
    private List<PolylinePoint> polyline;
    private List<RecommendedStationDTO> recommendedStations;
    private RecommendedStationDTO optimalStation;
    private Boolean needsChargingStop;
    private Double remainingRangeKm;
    private Double routeDistanceKm;
    private RouteSummaryDTO summary;
    private RouteBoundingBoxDTO boundingBox;
}
