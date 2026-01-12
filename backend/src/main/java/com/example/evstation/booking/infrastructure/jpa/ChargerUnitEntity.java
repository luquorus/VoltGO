package com.example.evstation.booking.infrastructure.jpa;

import com.example.evstation.booking.domain.ChargerUnitStatus;
import com.example.evstation.station.domain.PowerType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "charger_unit", indexes = {
    @Index(name = "idx_charger_unit_station_id", columnList = "station_id"),
    @Index(name = "idx_charger_unit_station_power", columnList = "station_id, power_type, power_kw"),
    @Index(name = "idx_charger_unit_station_version_id", columnList = "station_version_id")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChargerUnitEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;
    
    @Column(name = "station_version_id", nullable = false, columnDefinition = "UUID")
    private UUID stationVersionId;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "power_type", nullable = false)
    private PowerType powerType;
    
    @Column(name = "power_kw", precision = 10, scale = 2)
    private BigDecimal powerKw;
    
    @Column(name = "label", nullable = false)
    private String label;
    
    @Column(name = "price_per_slot", nullable = false)
    private Integer pricePerSlot;
    
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    @Builder.Default
    private ChargerUnitStatus status = ChargerUnitStatus.ACTIVE;
    
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
        if (status == null) {
            status = ChargerUnitStatus.ACTIVE;
        }
    }
}

