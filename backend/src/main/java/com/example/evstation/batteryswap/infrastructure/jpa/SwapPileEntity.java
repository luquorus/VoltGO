package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.SwapPileStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "swap_pile", uniqueConstraints = {
    @UniqueConstraint(name = "uk_swap_pile_station_index",
                      columnNames = {"station_id", "pile_index"})
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SwapPileEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "pile_index", nullable = false)
    private Integer pileIndex;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private SwapPileStatus status = SwapPileStatus.ACTIVE;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @OneToMany(mappedBy = "pileId", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("slotIndex ASC")
    @Builder.Default
    private List<BatterySlotEntity> slots = new ArrayList<>();

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        if (id == null) id = UUID.randomUUID();
        if (createdAt == null) createdAt = now;
        if (updatedAt == null) updatedAt = now;
        if (slots == null) slots = new ArrayList<>();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }

    public void addSlot(BatterySlotEntity slot) {
        slots.add(slot);
        slot.setPileId(this.id);
    }
}
