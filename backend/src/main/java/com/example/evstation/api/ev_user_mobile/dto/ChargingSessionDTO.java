package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class ChargingSessionDTO {
    private UUID sessionId;
    private UUID batterySlotId;
    private Integer startPercent;
    private Integer endPercent;
    private String status;
    private Instant startedAt;
    private Instant estimatedFullAt;
    private Instant completedAt;
}
