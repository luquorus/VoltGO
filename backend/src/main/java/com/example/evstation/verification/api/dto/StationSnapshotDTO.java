package com.example.evstation.verification.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StationSnapshotDTO {
    private Integer totalBatteries;
    private Double avgChargePowerKw;
    private Integer pileCount;
    private Integer slotCount;
    private String operatingHours;
    private Double parkingFee;
}
