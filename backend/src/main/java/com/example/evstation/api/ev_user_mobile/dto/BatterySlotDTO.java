package com.example.evstation.api.ev_user_mobile.dto;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class BatterySlotDTO {
    private UUID slotId;
    private Integer slotIndex;
    private UUID batteryId;
    private Integer batteryChargePercent;
    private BatterySlotStatus status;
    /**
     * Thời điểm ước tính pin sẽ đầy (100%).
     * Null nếu pin không đang sạc.
     */
    private Instant estimatedFullAt;
    /**
     * Thời điểm slot được cập nhật lần cuối.
     */
    private Instant updatedAt;
}
