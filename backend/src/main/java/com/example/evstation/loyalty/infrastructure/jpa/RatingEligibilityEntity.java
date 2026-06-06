package com.example.evstation.loyalty.infrastructure.jpa;

import com.example.evstation.loyalty.domain.EligibilityType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "rating_eligibility",
    uniqueConstraints = @UniqueConstraint(
        name = "uk_re_user_station_type_source",
        columnNames = {"user_id", "station_id", "source_type", "source_id"}
    ),
    indexes = {
        @Index(name = "idx_re_user", columnList = "user_id, is_rated"),
        @Index(name = "idx_re_station", columnList = "station_id")
    }
)
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RatingEligibilityEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;

    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;

    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", nullable = false)
    private EligibilityType sourceType;

    @Column(name = "source_id", nullable = false, columnDefinition = "UUID")
    private UUID sourceId;

    @Column(name = "eligible_at", nullable = false)
    private Instant eligibleAt;

    @Column(name = "is_rated", nullable = false)
    @Builder.Default
    private Boolean isRated = false;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) id = UUID.randomUUID();
        if (createdAt == null) createdAt = Instant.now();
    }
}
