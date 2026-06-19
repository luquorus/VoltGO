package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class BatterySwapSummaryDTO {
    private Integer totalPiles;
    private Integer totalSlots;
    private Integer availableBatteries;
    private Integer availableSlots;
    private java.math.BigDecimal avgChargePowerKw;
    private Integer basePriceVnd;
}
