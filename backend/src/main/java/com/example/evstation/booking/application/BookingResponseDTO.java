package com.example.evstation.booking.application;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class BookingResponseDTO {
    
    private UUID id;
    private UUID userId;
    private UUID stationId;
    private Instant startTime;
    private Instant endTime;
    private String status; // HOLD, CONFIRMED, CANCELLED, EXPIRED
    private Instant holdExpiresAt;
    private Instant createdAt;
}

