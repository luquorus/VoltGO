package com.example.evstation.api.admin_web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationTrustSummaryDTO {
    private int totalStations;
    private double averageScore;
    private int highCount;
    private int mediumCount;
    private int lowCount;
    private List<StationTrustStationSummaryDTO> topStations;
    private List<StationTrustStationSummaryDTO> bottomStations;
}
