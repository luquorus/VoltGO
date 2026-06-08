package com.example.evstation.loyalty.api.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class StationRatingSummaryDTO {
    private String stationId;
    private Double averageRating;
    private Integer totalRatings;
    private Integer r1;
    private Integer r2;
    private Integer r3;
    private Integer r4;
    private Integer r5;
}
