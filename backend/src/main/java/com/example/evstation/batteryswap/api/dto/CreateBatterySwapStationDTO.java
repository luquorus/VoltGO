package com.example.evstation.batteryswap.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
public class CreateBatterySwapStationDTO {

    @NotNull(message = "Station data is required")
    @Valid
    private StationDataDTO stationData;

    /** If true, station will be published immediately (auto-creates runtime piles/slots). */
    private Boolean publishImmediately = true; // ADMIN CREATED = auto-publish by default

    @Data
    public static class StationDataDTO {

        @NotBlank(message = "Name is required")
        @Size(min = 3, max = 255)
        private String name;

        @NotBlank(message = "Address is required")
        private String address;

        @NotNull @Valid
        private LocationDTO location;

        @NotBlank(message = "Operating hours is required")
        @Size(max = 100)
        private String operatingHours;

        @DecimalMin(value = "0")
        private BigDecimal parkingFee;

        @NotNull
        @Min(value = 1, message = "totalBatteries must be at least 1")
        private Integer totalBatteries;

        @NotNull
        @DecimalMin(value = "0.1", message = "avgChargePowerKw must be > 0")
        private BigDecimal avgChargePowerKw;

        /**
         * Battery capacity per slot in kWh. Defaults to 60.0 kWh when not provided.
         * Must be >= 1 if specified.
         */
        @DecimalMin(value = "1.0", message = "batteryCapacityKwh must be >= 1")
        private BigDecimal batteryCapacityKwh;

        /**
         * Parking type (e.g. FREE, PAID, STREET_PARKING). Defaults to FREE when not provided.
         */
        private String parking;

        @Size(max = 1000)
        private String note;

        /**
         * Optional custom pile layout. If null/empty → default layout is used
         * (ceil(totalBatteries/6) piles, 6 slots/pile, all slots use batteryCapacityKwh).
         * If provided, total slots across all piles must match totalBatteries.
         */
        @Valid
        private List<PileTemplateDTO> pileTemplates;
    }

    @Data
    public static class LocationDTO {
        @NotNull @DecimalMin("-90") @DecimalMax("90")
        private Double lat;

        @NotNull @DecimalMin("-180") @DecimalMax("180")
        private Double lng;
    }

    @Data
    public static class PileTemplateDTO {
        @NotNull(message = "pileIndex is required")
        @Min(value = 1, message = "pileIndex must be >= 1")
        private Integer pileIndex;

        @NotNull(message = "slotsPerPile is required")
        @Min(value = 1, message = "slotsPerPile must be >= 1")
        private Integer slotsPerPile;

        /**
         * Optional slot-level overrides. If null/empty, slots inherit batteryCapacityKwh
         * from StationDataDTO (or 60.0 kWh if not set there).
         */
        @Valid
        private List<SlotTemplateDTO> slots;
    }

    @Data
    public static class SlotTemplateDTO {
        @NotNull(message = "slotIndex is required")
        @Min(value = 0, message = "slotIndex must be >= 0")
        private Integer slotIndex;

        @NotNull(message = "batteryCapacityKwh is required")
        @DecimalMin(value = "1.0", message = "batteryCapacityKwh must be >= 1")
        private BigDecimal batteryCapacityKwh;
    }
}
