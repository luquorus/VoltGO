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

        @Size(max = 1000)
        private String note;
    }

    @Data
    public static class LocationDTO {
        @NotNull @DecimalMin("-90") @DecimalMax("90")
        private Double lat;

        @NotNull @DecimalMin("-180") @DecimalMax("180")
        private Double lng;
    }
}
