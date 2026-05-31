package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

@Data
@Builder
public class StationDetailDTO {
    private String stationId;
    private String name;
    private String address;
    private Double lat;
    private Double lng;
    private String operatingHours;
    private String parking;
    private String visibility;
    private String publicStatus;
    private Instant publishedAt;
    private List<PortInfoDTO> ports;
    private Integer trustScore;
    /** Trạm có dịch vụ BATTERY_SWAP trên version đã publish */
    private Boolean supportsBatterySwap;
    /** Chi tiết kho đổi pin khi supportsBatterySwap = true */
    private SwapServiceInfoDTO batterySwap;

    @Data
    @Builder
    public static class SwapServiceInfoDTO {
        private Integer totalBatteries;
        private Integer availableBatteries;
        private BigDecimal avgChargePowerKw;
    }
}

