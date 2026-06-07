package com.example.evstation.verification.api.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

/**
 * DTO for battery swap verification checkin request.
 */
@Data
public class BatterySwapCheckinRequestDTO {
    @NotNull(message = "Latitude is required")
    @DecimalMin(value = "-90", message = "Latitude must be >= -90")
    @DecimalMax(value = "90", message = "Latitude must be <= 90")
    private Double lat;

    @NotNull(message = "Longitude is required")
    @DecimalMin(value = "-180", message = "Longitude must be >= -180")
    @DecimalMax(value = "180", message = "Longitude must be <= 180")
    private Double lng;

    private String deviceNote;

    @Min(value = 0, message = "Actual total batteries must be >= 0")
    @Max(value = 1000, message = "Actual total batteries must be <= 1000")
    private Integer actualTotalBatteries;

    @Min(value = 0, message = "Actual available batteries must be >= 0")
    @Max(value = 1000, message = "Actual available batteries must be <= 1000")
    private Integer actualAvailableBatteries;

    @DecimalMin(value = "0", message = "Observed average charge power must be >= 0")
    @DecimalMax(value = "1000", message = "Observed average charge power must be <= 1000 kW")
    private Double observedAvgChargePowerKw;

    private List<ChecklistAnswer> checklistAnswers;
}
