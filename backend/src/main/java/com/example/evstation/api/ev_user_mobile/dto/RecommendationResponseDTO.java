package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class RecommendationResponseDTO {
    private RecommendationInputDTO input;
    private List<RecommendationResultDTO> results;
    
    @Data
    @Builder
    public static class RecommendationInputDTO {
        private LocationDTO currentLocation;
        private Double radiusKm;
        private Integer batteryPercent;
        private Double batteryCapacityKwh;
        private Integer targetPercent;
        private Double consumptionKwhPerKm;
        private Double averageSpeedKmph;
        private Double vehicleMaxChargeKw;
        private Integer limit;
        
        @Data
        @Builder
        public static class LocationDTO {
            private Double lat;
            private Double lng;
        }
    }
    
    @Data
    @Builder
    public static class RecommendationResultDTO {
        private String stationId;
        private String name;
        private String address;
        private Double lat;
        private Double lng;
        private Integer trustScore;
        private ChosenPortDTO chosenPort;
        private EstimateDTO estimate;
        private List<String> explain;
        private ChargingSummaryDTO chargingSummary;
        
        @Data
        @Builder
        public static class ChosenPortDTO {
            private String powerType; // DC or AC
            private BigDecimal powerKw; // null for AC
            private Double assumedEffectiveKw;
        }
        
        @Data
        @Builder
        public static class EstimateDTO {
            private Double distanceKm;
            private Integer travelMinutes;
            private Double neededKwh;
            private Integer chargeMinutes;
            private Integer totalMinutes;
        }
    }
}

