package com.example.evstation.api.admin_web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CsvImportResponseDTO {
    private int totalRows;
    private int successCount;
    private int failureCount;
    private List<ImportResult> results;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ImportResult {
        private int rowNumber;
        private String stationName;
        private boolean success;
        private String stationId; // UUID if successful
        private String errorMessage; // If failed
    }
}
