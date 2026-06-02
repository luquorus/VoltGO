package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.station.domain.WorkflowStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Entity representing a battery swap station version.
 * Tracks configuration versions for battery swap stations.
 */
@Entity
@Table(name = "battery_swap_station_version")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySwapStationVersionEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "version_no", nullable = false)
    @Builder.Default
    private Integer versionNo = 1;

    @Enumerated(EnumType.STRING)
    @Column(name = "workflow_status", nullable = false)
    @Builder.Default
    private WorkflowStatus workflowStatus = WorkflowStatus.DRAFT;

    @Column(name = "total_batteries", nullable = false)
    private Integer totalBatteries;

    @Column(name = "avg_charge_power_kw", nullable = false, precision = 6, scale = 2)
    private BigDecimal avgChargePowerKw;

    @Column(name = "operating_hours", nullable = false, length = 100)
    private String operatingHours;

    @Column(name = "parking_fee", precision = 10, scale = 2)
    private BigDecimal parkingFee;

    @Column(name = "note")
    private String note;

    @Column(name = "created_by", nullable = false, columnDefinition = "UUID")
    private UUID createdBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "submitted_at")
    private Instant submittedAt;

    @OneToMany(mappedBy = "stationVersion", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @Builder.Default
    private List<BatterySwapPileTemplateEntity> pileTemplates = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    @PreUpdate
    protected void onUpdate() {
        // Additional update logic if needed
    }

    /**
     * Get the total number of piles in this version.
     */
    public int getPileCount() {
        return pileTemplates != null ? pileTemplates.size() : 0;
    }

    /**
     * Get the total number of slots across all piles.
     */
    public int getTotalSlotCount() {
        if (pileTemplates == null) {
            return 0;
        }
        return pileTemplates.stream()
                .mapToInt(p -> p.getSlotsPerPile() != null ? p.getSlotsPerPile() : 0)
                .sum();
    }
}
