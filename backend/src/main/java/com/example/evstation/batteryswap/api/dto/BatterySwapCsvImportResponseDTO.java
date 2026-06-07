package com.example.evstation.batteryswap.api.dto;

import lombok.Builder;
import lombok.Data;
import java.util.List;

@Data @Builder
public class BatterySwapCsvImportResponseDTO {
    private int totalRows;
    private int successCount;
    private int failureCount;
    private List<ImportResult> results;

    @Data @Builder
    public static class ImportResult {
        private int rowNumber;
        private String stationName;
        private boolean success;
        private String stationId;
        private String errorMessage;
    }
}
