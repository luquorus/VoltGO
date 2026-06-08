package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class BatterySwapStationDetailDTO {
    private UUID stationId;
    private String name;
    private String address;
    private Double lat;
    private Double lng;
    private String operatingHours;
    private BigDecimal avgChargePowerKw;
    private Long basePriceVnd;
    private int totalPiles;
    private int totalSlots;
    private int availableSlots;
    private int availableBatteries;
    private List<SwapPileDTO> piles;
}
