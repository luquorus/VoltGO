package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.api.dto.BatterySwapCsvImportResponseDTO;
import com.example.evstation.batteryswap.api.dto.CreateBatterySwapStationDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BatterySwapCsvImportService {

    private final BatterySwapStationAdminService adminService;

    /**
     * Import battery swap stations from CSV file.
     * <p>CSV format (12 columns, header row required):</p>
     * <pre>
     * name,address,latitude,longitude,totalBatteries,avgChargePowerKw,operatingHours,
     * parkingFee,note,batteryCapacityKwh,parking,pileLayout
     * </pre>
     *
     * <p>Required columns: name, address, latitude, longitude, totalBatteries,
     * avgChargePowerKw, operatingHours (first 7).</p>
     *
     * <p>Optional columns (with defaults):</p>
     * <ul>
     *   <li>parkingFee — default empty (no fee)</li>
     *   <li>note — default empty</li>
     *   <li>batteryCapacityKwh — default 60.0</li>
     *   <li>parking — default FREE (allowed: FREE, PAID, STREET_PARKING)</li>
     *   <li>pileLayout — default auto-derived (6 slots/pile). Format:
     *       {@code pileCount:slotsPerPile} or {@code pileCount:slotsPerPile:capacityKwh}
     *       (e.g. {@code 4:6} = 4 piles × 6 slots = 24 batteries;
     *       {@code 3:8:60.0} = 3 piles × 8 slots × 60.0 kWh each)</li>
     * </ul>
     *
     * <p>CSV files with only the first 7-9 columns are still accepted (backward
     * compatible) — missing optional columns use defaults.</p>
     */
    @Transactional
    public BatterySwapCsvImportResponseDTO importStations(MultipartFile file, UUID adminId) {
        log.info("Importing battery swap stations from CSV file: {}", file.getOriginalFilename());

        List<BatterySwapCsvImportResponseDTO.ImportResult> results = new ArrayList<>();
        int rowNumber = 0;

        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8))) {

            // Skip header row
            String header = reader.readLine();
            if (header == null) {
                throw new IllegalArgumentException("CSV file is empty");
            }
            rowNumber++;

            String line;
            while ((line = reader.readLine()) != null) {
                rowNumber++;

                if (line.trim().isEmpty()) {
                    continue;
                }

                try {
                    CsvBatterySwapRow row = parseCsvLine(line);
                    CreateBatterySwapStationDTO createDTO = convertToCreateDTO(row);

                    var created = adminService.createStation(createDTO, adminId);

                    results.add(BatterySwapCsvImportResponseDTO.ImportResult.builder()
                            .rowNumber(rowNumber)
                            .stationName(row.name)
                            .success(true)
                            .stationId(created.getId())
                            .build());

                    log.info("Imported battery swap station from row {}: {}", rowNumber, row.name);

                } catch (Exception e) {
                    log.error("Failed to import battery swap station from row {}: {}", rowNumber, e.getMessage(), e);

                    String stationName = "Unknown";
                    try {
                        CsvBatterySwapRow tempRow = parseCsvLine(line);
                        stationName = tempRow.name != null ? tempRow.name : "Unknown";
                    } catch (Exception ignored) {
                        // Use default
                    }

                    results.add(BatterySwapCsvImportResponseDTO.ImportResult.builder()
                            .rowNumber(rowNumber)
                            .stationName(stationName)
                            .success(false)
                            .errorMessage(e.getMessage())
                            .build());
                }
            }

        } catch (Exception e) {
            log.error("Error reading CSV file", e);
            throw new RuntimeException("Failed to read CSV file: " + e.getMessage(), e);
        }

        int successCount = (int) results.stream()
                .filter(BatterySwapCsvImportResponseDTO.ImportResult::isSuccess)
                .count();
        int failureCount = results.size() - successCount;

        return BatterySwapCsvImportResponseDTO.builder()
                .totalRows(rowNumber - 1) // Exclude header
                .successCount(successCount)
                .failureCount(failureCount)
                .results(results)
                .build();
    }

    private CsvBatterySwapRow parseCsvLine(String line) {
        List<String> fields = new ArrayList<>();
        StringBuilder currentField = new StringBuilder();
        boolean inQuotes = false;

        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);

            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                fields.add(currentField.toString().trim());
                currentField = new StringBuilder();
            } else {
                currentField.append(c);
            }
        }
        fields.add(currentField.toString().trim());

        // Expect at least 7 required columns: name,address,latitude,longitude,totalBatteries,avgChargePowerKw,operatingHours
        if (fields.size() < 7) {
            throw new IllegalArgumentException("Invalid CSV row: expected at least 7 columns, got " + fields.size());
        }

        CsvBatterySwapRow row = new CsvBatterySwapRow();
        row.name = fields.get(0);
        row.address = fields.get(1);
        row.latitude = parseDouble(fields.get(2));
        row.longitude = parseDouble(fields.get(3));
        row.totalBatteries = parseInt(fields.get(4));
        row.avgChargePowerKw = parseDouble(fields.get(5));
        row.operatingHours = fields.get(6);
        row.parkingFee = fields.size() > 7 && !fields.get(7).isEmpty() ? parseDouble(fields.get(7)) : null;
        row.note = fields.size() > 8 ? fields.get(8) : null;
        row.batteryCapacityKwh = fields.size() > 9 && !fields.get(9).isEmpty() ? parseDouble(fields.get(9)) : null;
        row.parking = fields.size() > 10 ? fields.get(10) : null;
        row.pileLayout = fields.size() > 11 ? fields.get(11) : null;

        return row;
    }

    private double parseDouble(String value) {
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException("Invalid double value: " + value);
        }
        try {
            return Double.parseDouble(value.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid double value: " + value, e);
        }
    }

    private Integer parseInt(String value) {
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException("Invalid integer value: " + value);
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid integer value: " + value, e);
        }
    }

    private CreateBatterySwapStationDTO convertToCreateDTO(CsvBatterySwapRow row) {
        // Validate required fields
        if (row.name == null || row.name.trim().isEmpty()) {
            throw new IllegalArgumentException("Station name is required");
        }
        if (row.address == null || row.address.trim().isEmpty()) {
            throw new IllegalArgumentException("Station address is required");
        }
        if (row.latitude == null || row.longitude == null) {
            throw new IllegalArgumentException("Station location (latitude/longitude) is required");
        }
        if (row.totalBatteries == null || row.totalBatteries <= 0) {
            throw new IllegalArgumentException("totalBatteries must be at least 1");
        }
        if (row.avgChargePowerKw == null || row.avgChargePowerKw <= 0) {
            throw new IllegalArgumentException("avgChargePowerKw must be > 0");
        }
        if (row.operatingHours == null || row.operatingHours.trim().isEmpty()) {
            throw new IllegalArgumentException("Operating hours is required");
        }

        // Build location DTO
        CreateBatterySwapStationDTO.LocationDTO location = new CreateBatterySwapStationDTO.LocationDTO();
        location.setLat(row.latitude);
        location.setLng(row.longitude);

        // Build station data
        CreateBatterySwapStationDTO.StationDataDTO stationData = new CreateBatterySwapStationDTO.StationDataDTO();
        stationData.setName(row.name.trim());
        stationData.setAddress(row.address.trim());
        stationData.setLocation(location);
        stationData.setOperatingHours(row.operatingHours.trim());
        stationData.setTotalBatteries(row.totalBatteries);
        stationData.setAvgChargePowerKw(BigDecimal.valueOf(row.avgChargePowerKw));
        stationData.setParkingFee(row.parkingFee != null ? BigDecimal.valueOf(row.parkingFee) : null);
        stationData.setNote(row.note != null && !row.note.trim().isEmpty() ? row.note.trim() : null);

        // Optional: batteryCapacityKwh (per-slot capacity in kWh, defaults to 60.0 if null)
        BigDecimal batteryCapacityKwh = row.batteryCapacityKwh != null
                ? BigDecimal.valueOf(row.batteryCapacityKwh)
                : new BigDecimal("60.0");
        stationData.setBatteryCapacityKwh(batteryCapacityKwh);

        // Optional: parking type (FREE | PAID | STREET_PARKING | UNKNOWN, defaults to FREE)
        if (row.parking != null && !row.parking.isBlank()) {
            stationData.setParking(row.parking.trim());
        }

        // Optional: pile layout (custom pile/slot structure)
        if (row.pileLayout != null && !row.pileLayout.isBlank()) {
            List<CreateBatterySwapStationDTO.PileTemplateDTO> pileTemplates =
                    parsePileLayout(row.pileLayout, row.totalBatteries, batteryCapacityKwh);
            stationData.setPileTemplates(pileTemplates);
        }

        // Build create DTO
        CreateBatterySwapStationDTO createDTO = new CreateBatterySwapStationDTO();
        createDTO.setStationData(stationData);
        createDTO.setPublishImmediately(true); // Auto-publish imported stations

        return createDTO;
    }

    /**
     * Parse "pileCount:slotsPerPile" or "pileCount:slotsPerPile:capacityKwh" into
     * a list of PileTemplateDTO. Validates that pileCount × slotsPerPile == totalBatteries.
     */
    private List<CreateBatterySwapStationDTO.PileTemplateDTO> parsePileLayout(
            String pileLayout, int totalBatteries, BigDecimal defaultCapacityKwh) {
        String[] parts = pileLayout.split(":");
        if (parts.length < 2 || parts.length > 3) {
            throw new IllegalArgumentException(
                    "Invalid pileLayout '" + pileLayout + "': expected 'pileCount:slotsPerPile' or " +
                    "'pileCount:slotsPerPile:capacityKwh'");
        }

        int pileCount;
        int slotsPerPile;
        try {
            pileCount = Integer.parseInt(parts[0].trim());
            slotsPerPile = Integer.parseInt(parts[1].trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid pileLayout numbers: " + pileLayout, e);
        }

        BigDecimal slotCapacityKwh = defaultCapacityKwh;
        if (parts.length == 3 && !parts[2].trim().isEmpty()) {
            try {
                slotCapacityKwh = new BigDecimal(parts[2].trim());
            } catch (NumberFormatException e) {
                throw new IllegalArgumentException("Invalid capacityKwh in pileLayout: " + parts[2], e);
            }
        }

        if (pileCount < 1) {
            throw new IllegalArgumentException("pileCount must be >= 1, got " + pileCount);
        }
        if (slotsPerPile < 1) {
            throw new IllegalArgumentException("slotsPerPile must be >= 1, got " + slotsPerPile);
        }
        if (pileCount * slotsPerPile != totalBatteries) {
            throw new IllegalArgumentException(
                    "pileLayout mismatch: " + pileCount + " × " + slotsPerPile +
                    " = " + (pileCount * slotsPerPile) +
                    " but totalBatteries = " + totalBatteries);
        }
        log.debug("Parsed pileLayout: {} piles × {} slots/pile × {} kWh", pileCount, slotsPerPile, slotCapacityKwh);

        List<CreateBatterySwapStationDTO.PileTemplateDTO> piles = new ArrayList<>();
        for (int i = 0; i < pileCount; i++) {
            CreateBatterySwapStationDTO.PileTemplateDTO pile = new CreateBatterySwapStationDTO.PileTemplateDTO();
            pile.setPileIndex(i + 1);
            pile.setSlotsPerPile(slotsPerPile);
            // Generate slot entries for each pile so the admin service can
            // create matching battery_slot rows at runtime. Each slot inherits
            // batteryCapacityKwh from the layout default.
            List<CreateBatterySwapStationDTO.SlotTemplateDTO> slotEntries = new ArrayList<>();
            for (int j = 0; j < slotsPerPile; j++) {
                CreateBatterySwapStationDTO.SlotTemplateDTO slot = new CreateBatterySwapStationDTO.SlotTemplateDTO();
                slot.setSlotIndex(j);
                slot.setBatteryCapacityKwh(slotCapacityKwh);
                slotEntries.add(slot);
            }
            pile.setSlots(slotEntries);
            piles.add(pile);
        }
        return piles;
    }

    // Helper class for CSV row
    private static class CsvBatterySwapRow {
        String name;
        String address;
        Double latitude;
        Double longitude;
        Integer totalBatteries;
        Double avgChargePowerKw;
        String operatingHours;
        Double parkingFee;
        String note;
        Double batteryCapacityKwh;
        String parking;
        String pileLayout;
    }
}
