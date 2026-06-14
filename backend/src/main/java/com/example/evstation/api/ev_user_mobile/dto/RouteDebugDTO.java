package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class RouteDebugDTO {
    private String routeWkt;
    private int bufferMeters;
    private long totalPublishedStations;
    private int stationsInCorridor;
    private int stationsAfterBatteryFilter;
    private List<RecommendedStationDTO> finalRecommended;
    private String traceId;
}
