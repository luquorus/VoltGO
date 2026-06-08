package com.example.evstation.loyalty.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_badge",
    uniqueConstraints = @UniqueConstraint(name = "uk_user_badge", columnNames = {"user_id", "badge_id"})
)
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserBadgeEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;

    @Column(name = "badge_id", nullable = false, columnDefinition = "UUID")
    private UUID badgeId;

    @Column(name = "earned_at", nullable = false)
    private Instant earnedAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) id = UUID.randomUUID();
        if (earnedAt == null) earnedAt = Instant.now();
    }
}
