package com.example.evstation.api.admin_web.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class StationTrustStationSummaryDTO {
    private String stationId;
    private String stationName;
    private double score;
    private String level;
}
