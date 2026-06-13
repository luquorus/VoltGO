package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class RecommendedStationDTO {
    private String stationId;
    private String name;
    private String address;
    private double lat;
    private double lng;
    private double distanceFromRouteMeters;
    private double detourMeters;
    private double totalPowerKw;
    private int availablePorts;
    private int totalPorts;
    private List<String> connectorTypes;
    private Double rating;
    private int estimatedArrivalMinutes;
    private int waitTimeMinutes;
    private int estimatedChargeMinutes;
    private double score;
    private Double distanceKm;
    private Double optimalChargingStopMinutes;
    private Boolean isOptimalStop;
    private Double remainingRangeAfterStopKm;
    private Double estimatedBatteryAtArrival;
    private String recommendationReason;
    private Boolean isRecommended;

    // Battery swap specific fields
    private ServiceType serviceType;
    private Integer availableBatteries;
    private Integer totalBatteries;
    private BigDecimal avgChargePowerKw;
    private Long basePriceVnd;
    private Integer estimatedSwapMinutes;

    public enum ServiceType {
        CHARGING,
        BATTERY_SWAP,
        BOTH
    }
}
