package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyBadgeEntity;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
public class UserBadgeDTO {
    private String id;
    private String code;
    private String name;
    private String description;
    private String tier;
    private String icon;
    private Instant earnedAt;

    public static UserBadgeDTO fromEntity(LoyaltyBadgeEntity badge, Instant earnedAt) {
        return UserBadgeDTO.builder()
                .id(badge.getId().toString())
                .code(badge.getCode())
                .name(badge.getName())
                .description(badge.getDescription())
                .tier(badge.getTier().name())
                .icon(badge.getIcon())
                .earnedAt(earnedAt)
                .build();
    }
}
