package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.ChangeRequestStatus;
import com.example.evstation.batteryswap.domain.ChangeRequestType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Entity representing a battery swap change request.
 * Tracks changes to battery swap station configurations.
 */
@Entity
@Table(name = "battery_swap_change_request")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySwapChangeRequestEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ChangeRequestType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ChangeRequestStatus status = ChangeRequestStatus.DRAFT;

    @Column(name = "station_id", columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "proposed_version_id", nullable = false, columnDefinition = "UUID")
    private UUID proposedVersionId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "proposed_version_id", insertable = false, updatable = false)
    private BatterySwapStationVersionEntity proposedVersion;

    @Column(name = "submitted_by", nullable = false, columnDefinition = "UUID")
    private UUID submittedBy;

    @Column(name = "risk_score", nullable = false)
    @Builder.Default
    private Integer riskScore = 0;

    @Column(name = "risk_reasons", columnDefinition = "text")
    @Builder.Default
    private String riskReasons = "[]";

    @Column(name = "admin_note")
    private String adminNote;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "submitted_at")
    private Instant submittedAt;

    @Column(name = "decided_at")
    private Instant decidedAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    /**
     * Check if this is a new station creation request.
     */
    public boolean isNewStationRequest() {
        return type == ChangeRequestType.CREATE_BATTERY_SWAP_STATION;
    }

    /**
     * Check if this request requires admin review based on status.
     */
    public boolean requiresAdminReview() {
        return status == ChangeRequestStatus.SUBMITTED || status == ChangeRequestStatus.IN_REVIEW;
    }
}
