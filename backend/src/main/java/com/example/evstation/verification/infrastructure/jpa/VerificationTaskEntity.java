package com.example.evstation.verification.infrastructure.jpa;

import com.example.evstation.verification.domain.VerificationTaskStatus;
import com.example.evstation.verification.domain.VerificationType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "verification_task")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VerificationTaskEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;
    
    @Column(name = "change_request_id", columnDefinition = "UUID")
    private UUID changeRequestId;
    
    @Column(nullable = false)
    @Builder.Default
    private Integer priority = 3;
    
    @Column(name = "sla_due_at")
    private Instant slaDueAt;
    
    @Column(name = "assigned_to", columnDefinition = "UUID")
    private UUID assignedTo;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private VerificationTaskStatus status = VerificationTaskStatus.OPEN;

    @Enumerated(EnumType.STRING)
    @Column(name = "verification_type", nullable = false)
    @Builder.Default
    private VerificationType verificationType = VerificationType.CHARGING_STATION;

    @Column(name = "battery_swap_change_request_id", columnDefinition = "UUID")
    private UUID batterySwapChangeRequestId;

    @Column(name = "battery_swap_station_snapshot", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String batterySwapStationSnapshot;

    @Column(name = "checklist_json", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String checklistJson;

    @Column(name = "station_snapshot_json", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String stationSnapshotJson;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}

