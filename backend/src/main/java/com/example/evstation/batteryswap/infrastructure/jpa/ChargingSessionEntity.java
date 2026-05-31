package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.ChargingSessionStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "charging_session")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChargingSessionEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "battery_slot_id", nullable = false, columnDefinition = "UUID")
    private UUID batterySlotId;

    @Column(name = "start_percent", nullable = false)
    @Builder.Default
    private Integer startPercent = 0;

    @Column(name = "end_percent")
    private Integer endPercent;

    @Column(name = "start_kwh", precision = 8, scale = 4)
    private BigDecimal startKwh;

    @Column(name = "end_kwh", precision = 8, scale = 4)
    private BigDecimal endKwh;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ChargingSessionStatus status = ChargingSessionStatus.CHARGING;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "estimated_full_at")
    private Instant estimatedFullAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        if (id == null) id = UUID.randomUUID();
        if (startedAt == null) startedAt = now;
    }
}
