package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Trạm hỗ trợ đổi pin (cho danh sách "trạm gần").
 */
@Data
@Builder
public class BatterySwapStationDTO {
    private UUID stationId;
    private String name;
    private String address;
    private Double lat;
    private Double lng;
    private Double distanceKm;
    private Integer totalBatteries;
    private Integer availableBatteries;
    private BigDecimal avgChargePowerKw;
    /** Phí đổi pin một lượt (VND), giá trị hiện hành cấu hình ở backend. */
    private Long basePriceVnd;
    private Integer totalPiles;
    private Integer availableSlots;
    private Integer totalSlots;
    /** Provider sở hữu trạm (NULL nếu import CSV trước khi áp dụng P1 fix). */
    private String providerId;
}
