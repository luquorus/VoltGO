package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "battery_slot", uniqueConstraints = {
    @UniqueConstraint(name = "uk_battery_slot_pile_index",
                      columnNames = {"pile_id", "slot_index"})
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySlotEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "pile_id", nullable = false, columnDefinition = "UUID")
    private UUID pileId;

    @Column(name = "slot_index", nullable = false)
    private Integer slotIndex;

    @Column(name = "battery_id", columnDefinition = "UUID")
    private UUID batteryId;

    @Column(name = "battery_serial_number")
    private String batterySerialNumber;

    @Column(name = "battery_capacity_kwh", precision = 6, scale = 2)
    @Builder.Default
    private BigDecimal batteryCapacityKwh = BigDecimal.valueOf(60.0);

    @Column(name = "battery_charge_percent", nullable = false)
    @Builder.Default
    private Integer batteryChargePercent = 100;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private BatterySlotStatus status = BatterySlotStatus.AVAILABLE;

    /**
     * Thời điểm bắt đầu sạc (dùng để tính % pin hiện tại trong simulation).
     * Set khi slot chuyển sang CHARGING hoặc SWAPPED_OUT.
     */
    @Column(name = "charging_started_at")
    private Instant chargingStartedAt;

    /**
     * Thời điểm ước tính pin sẽ đầy (100%).
     * Tính dựa trên chargingStartedAt + chargeDurationMinutes.
     * Trả về null nếu pin không đang sạc.
     */
    @Column(name = "estimated_full_at")
    private Instant estimatedFullAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        if (id == null) id = UUID.randomUUID();
        if (updatedAt == null) updatedAt = now;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
