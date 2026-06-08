package com.example.evstation.batteryswap.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Entity representing a battery swap slot template.
 * Defines the configuration for individual battery slots within a pile template.
 */
@Entity
@Table(name = "battery_swap_slot_template")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySwapSlotTemplateEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pile_template_id", nullable = false)
    private BatterySwapPileTemplateEntity pileTemplate;

    @Column(name = "slot_index", nullable = false)
    private Integer slotIndex;

    @Column(name = "battery_capacity_kwh", nullable = false, precision = 6, scale = 2)
    @Builder.Default
    private BigDecimal batteryCapacityKwh = new BigDecimal("60.0");

    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
    }
}
