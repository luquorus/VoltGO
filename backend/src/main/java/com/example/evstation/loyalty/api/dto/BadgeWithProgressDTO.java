package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyBadgeEntity;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class BadgeWithProgressDTO {
    private String id;
    private String code;
    private String name;
    private String tier;
    private String description;
    private String icon;
    private Integer currentValue;
    private Integer targetValue;
    private Integer pointsBonus;
    private Boolean isEarned;
    private String earnedAt;
}
