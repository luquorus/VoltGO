package com.example.evstation.loyalty.infrastructure.jpa;

import com.example.evstation.loyalty.domain.BadgeCriteriaType;
import com.example.evstation.loyalty.domain.BadgeTier;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "loyalty_badge", indexes = {
    @Index(name = "idx_lb_criteria", columnList = "criteria_type, criteria_value")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoyaltyBadgeEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(nullable = false, unique = true)
    private String code;

    @Column(nullable = false)
    private String name;

    @Column
    private String description;

    @Column
    private String icon;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BadgeTier tier;

    @Enumerated(EnumType.STRING)
    @Column(name = "criteria_type", nullable = false)
    private BadgeCriteriaType criteriaType;

    @Column(name = "criteria_value", nullable = false)
    private Integer criteriaValue;

    @Column(name = "points_bonus", nullable = false)
    @Builder.Default
    private Integer pointsBonus = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) id = UUID.randomUUID();
        if (createdAt == null) createdAt = Instant.now();
    }
}
