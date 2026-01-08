package com.example.evstation.api.admin_web.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.Map;

/**
 * Full trust score breakdown for admin view.
 */
@Data
@Builder
public class StationTrustDTO {
    private String stationId;
    private Integer score;
    private Map<String, Object> breakdown;
    private Instant updatedAt;
}

