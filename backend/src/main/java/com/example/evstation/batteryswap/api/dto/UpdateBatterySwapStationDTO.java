package com.example.evstation.batteryswap.api.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

/**
 * DTO for updating a battery swap station directly (admin edit).
 * Admin edits create a new version of the station.
 */
@Data
public class UpdateBatterySwapStationDTO {

    @NotNull(message = "Station data is required")
    @Valid
    private StationDataDTO stationData;

    /**
     * If true, the new version will be published immediately (PUBLISHED).
     * If false or null, creates a DRAFT version.
     */
    private Boolean publishImmediately = false;

    @Data
    public static class StationDataDTO {

        @NotBlank(message = "Name is required")
        @Size(min = 3, max = 255, message = "Name must be between 3 and 255 characters")
        private String name;

        @NotBlank(message = "Address is required")
        private String address;

        @NotNull(message = "Location is required")
        @Valid
        private LocationDTO location;

        /**
         * Operating hours string, e.g. "06:00-22:00".
         */
        @NotBlank(message = "Operating hours is required")
        @Size(max = 100, message = "operatingHours must be at most 100 characters")
        private String operatingHours;

        /**
         * Parking type (e.g. FREE, PAID, STREET_PARKING).
         * Defaults to FREE if not provided.
         */
        private String parking;

        /**
         * Parking fee in VND.
         */
        @DecimalMin(value = "0", message = "parkingFee must be >= 0")
        private BigDecimal parkingFee;

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
         * Optional note.
         */
        @Size(max = 1000, message = "note must be at most 1000 characters")
        private String note;

        /**
         * Pile templates — defines the pile/slot layout.
         * If provided, total slots across all piles must match totalBatteries.
         * If not provided, a default layout is created.
         */
        @Valid
        private List<PileTemplateDTO> pileTemplates;
    }

    @Data
    public static class LocationDTO {
        @NotNull(message = "Latitude is required")
        @DecimalMin(value = "-90", message = "Latitude must be >= -90")
        @DecimalMax(value = "90", message = "Latitude must be <= 90")
        private Double lat;

        @NotNull(message = "Longitude is required")
        @DecimalMin(value = "-180", message = "Longitude must be >= -180")
        @DecimalMax(value = "180", message = "Longitude must be <= 180")
        private Double lng;
    }

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
