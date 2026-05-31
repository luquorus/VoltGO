package com.example.evstation.api.ev_user_mobile.dto;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Data
public class BatterySwapReserveRequestDTO {
    @NotNull
    private UUID stationId;

    /**
     * Thời gian user hẹn đến trạm để đổi pin.
     * BẮT BUỘC. Phải >= thời gian hiện tại.
     */
    @NotNull(message = "arrival time is required")
    @FutureOrPresent(message = "arrival time must be now or in the future")
    private Instant expectedArrivalAt;

    @Min(0)
    @Max(100)
    private Integer requestedBatteryPercent;

    @Min(1)
    private BigDecimal batteryCapacityKwh;

    private UUID pileId;

    private UUID slotId;

    private String note;
}
