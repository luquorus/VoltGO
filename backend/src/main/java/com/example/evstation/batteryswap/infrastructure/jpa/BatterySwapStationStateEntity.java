package com.example.evstation.batteryswap.infrastructure.jpa;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "battery_swap_station_state")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySwapStationStateEntity {

    @Id
    @Column(name = "station_id", columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "total_batteries", nullable = false)
    @Builder.Default
    private Integer totalBatteries = 20;

    @Column(name = "available_batteries", nullable = false)
    @Builder.Default
    private Integer availableBatteries = 10;

    @Column(name = "avg_charge_power_kw", nullable = false)
    @Builder.Default
    private BigDecimal avgChargePowerKw = BigDecimal.valueOf(35.0);

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        if (updatedAt == null) {
            updatedAt = Instant.now();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
