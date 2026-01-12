package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.ChangeRequestStatus;
import com.example.evstation.station.domain.ChangeRequestType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "change_request")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChangeRequestEntity {
    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ChangeRequestType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ChangeRequestStatus status;

    @Column(name = "station_id", columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "proposed_station_version_id", nullable = false, columnDefinition = "UUID")
    private UUID proposedStationVersionId;

    @Column(name = "submitted_by", nullable = false, columnDefinition = "UUID")
    private UUID submittedBy;

    @Column(name = "risk_score", nullable = false)
    @Builder.Default
    private Integer riskScore = 0;

    @Column(name = "risk_reasons", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    @Builder.Default
    private List<String> riskReasons = List.of();

    @Column(name = "admin_note")
    private String adminNote;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "submitted_at")
    private Instant submittedAt;

    @Column(name = "decided_at")
    private Instant decidedAt;

    @Column(name = "image_urls", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    @Builder.Default
    private List<String> imageUrls = List.of();

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}

