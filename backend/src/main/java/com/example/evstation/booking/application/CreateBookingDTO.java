package com.example.evstation.booking.application;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
public class CreateBookingDTO {
    
    @NotNull(message = "stationId is required")
    private UUID stationId;
    
    @NotNull(message = "chargerUnitId is required")
    private UUID chargerUnitId;
    
    @NotNull(message = "startTime is required")
    private Instant startTime;
    
    @NotNull(message = "endTime is required")
    private Instant endTime;
}

