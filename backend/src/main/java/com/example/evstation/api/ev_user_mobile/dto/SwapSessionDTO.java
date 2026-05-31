package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class SwapSessionDTO {
    private UUID sessionId;
    private UUID reservationId;
    private String swapCode;
    private String status;
    private Instant expiresAt;
    private Instant startedAt;
    private Instant completedAt;
}
