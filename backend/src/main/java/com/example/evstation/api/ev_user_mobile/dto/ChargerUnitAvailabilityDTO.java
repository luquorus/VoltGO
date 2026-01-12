package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class ChargerUnitAvailabilityDTO {
    private ChargerUnitDTO chargerUnit;
    private List<AvailabilitySlotDTO> slots;
}

