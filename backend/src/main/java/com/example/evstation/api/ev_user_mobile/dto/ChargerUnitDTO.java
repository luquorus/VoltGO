package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
public class ChargerUnitDTO {
    private UUID id;
    private UUID stationId;
    private String label;
    private String powerType; // DC or AC
    private BigDecimal powerKw;
    private Integer pricePerSlot; // VND per slot (30 minutes)
    private String status; // ACTIVE, INACTIVE, MAINTENANCE
}

