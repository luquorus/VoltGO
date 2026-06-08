package com.example.evstation.loyalty.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "loyalty_user_profile")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoyaltyUserProfileEntity {

    @Id
    @Column(name = "user_id", columnDefinition = "UUID")
    private UUID userId;

    @Column(name = "current_points", nullable = false)
    @Builder.Default
    private Integer currentPoints = 0;

    @Column(name = "lifetime_points", nullable = false)
    @Builder.Default
    private Integer lifetimePoints = 0;

    @Column(name = "total_ratings", nullable = false)
    @Builder.Default
    private Integer totalRatings = 0;

    @Column(name = "total_bookings", nullable = false)
    @Builder.Default
    private Integer totalBookings = 0;

    @Column(name = "total_swaps", nullable = false)
    @Builder.Default
    private Integer totalSwaps = 0;

    @Column(name = "total_contributions", nullable = false)
    @Builder.Default
    private Integer totalContributions = 0;

    @Column(name = "last_activity_at")
    private Instant lastActivityAt;

    @Column(nullable = false)
    @Builder.Default
    private Integer level = 1;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
