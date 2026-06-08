package com.example.evstation.batteryswap.api.dto;

import com.example.evstation.batteryswap.domain.ChangeRequestType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Data
public class CreateBatterySwapCRDTO {

    /**
     * Type of change request: CREATE_BATTERY_SWAP_STATION or UPDATE_BATTERY_SWAP_STATION.
     */
    @NotNull(message = "Type is required")
    private ChangeRequestType type;

    /**
     * Station ID — required for UPDATE_STATION, null for CREATE_STATION.
     */
    private UUID stationId;

    /**
     * Total number of batteries in the station.
     */
    @NotNull(message = "totalBatteries is required")
    @Min(value = 1, message = "totalBatteries must be at least 1")
    private Integer totalBatteries;

    /**
     * Average charging power in kW.
     */
    @NotNull(message = "avgChargePowerKw is required")
    @DecimalMin(value = "0.1", message = "avgChargePowerKw must be > 0")
    private BigDecimal avgChargePowerKw;

    /**
     * Operating hours string, e.g. "06:00-22:00".
     */
    @NotBlank(message = "operatingHours is required")
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
     * If not provided, a default layout (ceil(totalBatteries/6) piles) is created.
     */
    @Valid
    private List<PileTemplateDTO> pileTemplates;

    /**
     * When true (admin flow): CR is immediately submitted, approved, and published.
     * When false (EV user flow): CR is created as DRAFT and goes through the workflow step by step.
     * Defaults to true when submitted by ADMIN.
     */
    private Boolean submitImmediately;

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
