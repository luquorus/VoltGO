package com.example.evstation.api.admin_web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.Map;

/**
 * Full trust score breakdown for admin view.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationTrustDTO {
    private String stationId;
    private Integer score;
    private Map<String, Object> breakdown;
    private Instant updatedAt;
}
