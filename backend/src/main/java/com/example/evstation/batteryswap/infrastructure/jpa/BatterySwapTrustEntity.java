package com.example.evstation.batteryswap.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Entity representing trust scores for battery swap stations.
 * Tracks trust metrics and breakdowns for battery swap providers.
 */
@Entity
@Table(name = "battery_swap_trust")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySwapTrustEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "station_id", nullable = false, columnDefinition = "UUID", unique = true)
    private UUID stationId;

    @Column(name = "score", nullable = false)
    @Builder.Default
    private Integer score = 50;

    @Column(name = "breakdown", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    @Builder.Default
    private Map<String, Integer> breakdown = new HashMap<>();

    @Column(name = "last_event_at")
    private Instant lastEventAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (updatedAt == null) {
            updatedAt = Instant.now();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    /**
     * Check if trust score indicates high trust (score >= 70).
     */
    public boolean isHighTrust() {
        return score >= 70;
    }

    /**
     * Check if trust score indicates low trust (score < 30).
     */
    public boolean isLowTrust() {
        return score < 30;
    }

    /**
     * Get trust level based on score.
     */
    public String getTrustLevel() {
        if (score >= 70) return "HIGH";
        if (score >= 30) return "MEDIUM";
        return "LOW";
    }

    /**
     * Get a specific breakdown value by category.
     */
    public Integer getBreakdownValue(String category) {
        return breakdown != null ? breakdown.get(category) : null;
    }
}
