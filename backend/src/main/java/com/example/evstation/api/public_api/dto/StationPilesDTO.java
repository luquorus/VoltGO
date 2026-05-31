package com.example.evstation.api.public_api.dto;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.domain.SwapPileStatus;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class StationPilesDTO {
    private UUID stationId;
    private String stationName;
    private List<PileDTO> piles;

    @Data
    @Builder
    public static class PileDTO {
        private UUID pileId;
        private Integer pileIndex;
        private SwapPileStatus status;
        private List<SlotDTO> slots;
    }

    @Data
    @Builder
    public static class SlotDTO {
        private UUID slotId;
        private Integer slotIndex;
        private UUID batteryId;
        private Integer batteryChargePercent;
        private BatterySlotStatus status;
        private Instant estimatedFullAt;
        private Instant updatedAt;
    }
}
