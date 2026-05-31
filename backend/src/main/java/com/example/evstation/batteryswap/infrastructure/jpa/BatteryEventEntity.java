package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.BatteryEventType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "battery_event")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatteryEventEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "battery_slot_id", nullable = false, columnDefinition = "UUID")
    private UUID batterySlotId;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false)
    private BatteryEventType eventType;

    @Column(name = "old_state")
    private String oldState;

    @Column(name = "new_state")
    private String newState;

    @Column(name = "old_percent")
    private Integer oldPercent;

    @Column(name = "new_percent")
    private Integer newPercent;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private Map<String, Object> metadata;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "created_by", columnDefinition = "UUID")
    private UUID createdBy;

    @Column(name = "actor_type")
    private String actorType;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        if (id == null) id = UUID.randomUUID();
        if (createdAt == null) createdAt = now;
    }
}
