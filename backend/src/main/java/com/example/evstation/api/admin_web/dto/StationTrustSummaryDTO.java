package com.example.evstation.api.admin_web.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class StationTrustSummaryDTO {
    private int totalStations;
    private double averageScore;
    private int highCount;
    private int mediumCount;
    private int lowCount;
    private List<StationTrustStationSummaryDTO> topStations;
    private List<StationTrustStationSummaryDTO> bottomStations;
}
