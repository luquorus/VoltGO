package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
public class AvailabilitySlotDTO {
    private Instant startTime;
    private Instant endTime;
    private String status; // AVAILABLE, HELD, BOOKED
}

