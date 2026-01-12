package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Data
@Builder
public class AvailabilityResponseDTO {
    private UUID stationId;
    private String date; // YYYY-MM-DD
    private List<Instant> slotTimes; // List of time points for slots
    private List<ChargerUnitAvailabilityDTO> availability; // Availability matrix per charger unit
}

