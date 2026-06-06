package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyUserProfileEntity;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;

@Data
@Builder
public class LoyaltyUserProfileDTO {
    private String userId;
    private Integer currentPoints;
    private Integer lifetimePoints;
    private Integer totalRatings;
    private Integer totalBookings;
    private Integer totalSwaps;
    private Integer totalContributions;
    private Integer level;
    private String levelName;
    private List<UserBadgeDTO> badges;
    private Integer pointsToNextLevel;
    private Integer pointsNeededForNextLevel;

    private static final int[] LEVEL_THRESHOLDS = {0, 100, 500, 1500, 5000, 15000};

    public static LoyaltyUserProfileDTO fromEntity(LoyaltyUserProfileEntity entity, List<UserBadgeDTO> badges, String levelName) {
        int lifetime = entity.getLifetimePoints();
        int currentLevel = entity.getLevel() != null ? entity.getLevel() : 1;
        int nextThreshold = currentLevel < LEVEL_THRESHOLDS.length ? LEVEL_THRESHOLDS[currentLevel] : LEVEL_THRESHOLDS[LEVEL_THRESHOLDS.length - 1] + 5000;
        int currentThreshold = currentLevel > 0 ? LEVEL_THRESHOLDS[currentLevel - 1] : 0;
        int range = nextThreshold - currentThreshold;
        int needed = nextThreshold - lifetime;
        return LoyaltyUserProfileDTO.builder()
                .userId(entity.getUserId().toString())
                .currentPoints(entity.getCurrentPoints())
                .lifetimePoints(entity.getLifetimePoints())
                .totalRatings(entity.getTotalRatings())
                .totalBookings(entity.getTotalBookings())
                .totalSwaps(entity.getTotalSwaps())
                .totalContributions(entity.getTotalContributions())
                .level(entity.getLevel())
                .levelName(levelName)
                .badges(badges)
                .pointsToNextLevel(Math.max(0, needed))
                .pointsNeededForNextLevel(Math.max(1, range))
                .build();
    }
}
