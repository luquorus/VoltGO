package com.example.evstation.api.ev_user_mobile.dto;

import com.example.evstation.batteryswap.domain.SwapPileStatus;
import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.UUID;

@Data
@Builder
public class SwapPileDTO {
    private UUID pileId;
    private Integer pileIndex;
    private SwapPileStatus status;
    private List<BatterySlotDTO> slots;
}
