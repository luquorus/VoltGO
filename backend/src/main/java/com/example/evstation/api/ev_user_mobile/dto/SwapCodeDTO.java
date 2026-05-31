package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class SwapCodeDTO {
    private UUID reservationId;
    private String swapCode;
    private Instant expiresAt;
    private Instant deadlineAt;
    private String stationName;
    private Integer pileIndex;
    private Integer slotIndex;
}
