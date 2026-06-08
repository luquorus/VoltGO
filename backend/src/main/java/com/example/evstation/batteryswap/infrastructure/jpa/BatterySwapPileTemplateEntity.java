package com.example.evstation.batteryswap.infrastructure.jpa;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Entity representing a battery swap pile template.
 * Defines the configuration for swap piles within a station version.
 */
@Entity
@Table(name = "battery_swap_pile_template")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySwapPileTemplateEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "station_version_id", nullable = false)
    private BatterySwapStationVersionEntity stationVersion;

    @Column(name = "pile_index", nullable = false)
    private Integer pileIndex;

    @Column(name = "slots_per_pile", nullable = false)
    @Builder.Default
    private Integer slotsPerPile = 6;

    @OneToMany(mappedBy = "pileTemplate", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<BatterySwapSlotTemplateEntity> slotTemplates = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
    }

    /**
     * Get the number of slot templates defined for this pile.
     */
    public int getSlotTemplateCount() {
        return slotTemplates != null ? slotTemplates.size() : 0;
    }
}
