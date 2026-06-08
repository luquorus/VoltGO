package com.example.evstation.batteryswap.application;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

/**
 * DTO for battery swap trust score with breakdown by dimensions.
 */
public record BatterySwapTrustScoreDTO(
        UUID stationId,
        int score,
        Map<String, Integer> breakdown,
        Instant updatedAt,
        String level
) {
    /** Compact canonical constructor — computes level from totalScore. */
    public BatterySwapTrustScoreDTO(UUID stationId, int totalScore, Map<String, Integer> breakdown, Instant updatedAt) {
        this(stationId, totalScore, breakdown, updatedAt, computeLevel(totalScore));
    }

    private static String computeLevel(int score) {
        if (score >= 90) return "EXCELLENT";
        if (score >= 70) return "GOOD";
        if (score >= 50) return "FAIR";
        if (score > 0) return "POOR";
        return "NEW";
    }
}
