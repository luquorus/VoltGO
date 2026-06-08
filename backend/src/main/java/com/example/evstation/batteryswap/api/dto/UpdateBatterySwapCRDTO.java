package com.example.evstation.batteryswap.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * DTO for updating a DRAFT battery swap change request.
 * All fields are optional — only provided fields are updated.
 */
@Data
public class UpdateBatterySwapCRDTO {

    /**
     * Total number of batteries in the station.
     */
    @Min(value = 1, message = "totalBatteries must be at least 1")
    private Integer totalBatteries;

    /**
     * Average charging power in kW.
     */
    @DecimalMin(value = "0.1", message = "avgChargePowerKw must be > 0")
    private BigDecimal avgChargePowerKw;

    /**
     * Operating hours string, e.g. "06:00-22:00".
     */
    @Size(max = 100, message = "operatingHours must be at most 100 characters")
    private String operatingHours;

    /**
     * Optional parking fee.
     */
    @DecimalMin(value = "0", message = "parkingFee must be >= 0")
    private BigDecimal parkingFee;

    /**
     * Optional provider note.
     */
    @Size(max = 1000, message = "note must be at most 1000 characters")
    private String note;

    /**
     * Pile templates — defines the pile/slot layout.
     * If provided, total slots across all piles must match totalBatteries.
     */
    @Valid
    private List<PileTemplateDTO> pileTemplates;

    /**
     * Admin note for the change request.
     */
    @Size(max = 2000, message = "adminNote must be at most 2000 characters")
    private String adminNote;

    @Data
    public static class PileTemplateDTO {
        @NotNull(message = "pileIndex is required")
        private Integer pileIndex;

        @NotNull(message = "slotsPerPile is required")
        @Min(value = 1, message = "slotsPerPile must be at least 1")
        private Integer slotsPerPile;

        @Valid
        private List<SlotTemplateDTO> slots;
    }

    @Data
    public static class SlotTemplateDTO {
        @NotNull(message = "slotIndex is required")
        private Integer slotIndex;

        @NotNull(message = "batteryCapacityKwh is required")
        @DecimalMin(value = "1", message = "batteryCapacityKwh must be >= 1")
        private BigDecimal batteryCapacityKwh;
    }
}
