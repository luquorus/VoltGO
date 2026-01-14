package com.example.evstation.station.application;

import com.example.evstation.api.admin_web.dto.AdminStationDTO;
import com.example.evstation.api.admin_web.dto.CreateStationDTO;
import com.example.evstation.api.admin_web.dto.CsvImportResponseDTO;
import com.example.evstation.station.domain.*;
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
public class CsvImportService {
    
    private final AdminStationService adminStationService;
    
    /**
     * Import stations from CSV file
     * Expected format: name,address,latitude,longitude,ports_250kw,ports_180kw,ports_150kw,ports_120kw,ports_80kw,ports_60kw,ports_40kw,ports_ac,operatingHours,parking,stationType,status
     */
    @Transactional
    public CsvImportResponseDTO importStations(MultipartFile file, UUID adminId) {
        log.info("Importing stations from CSV file: {}", file.getOriginalFilename());
        
        List<CsvImportResponseDTO.ImportResult> results = new ArrayList<>();
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
                    CsvStationRow row = parseCsvLine(line);
                    CreateStationDTO createDTO = convertToCreateDTO(row);
                    
                    AdminStationDTO created = adminStationService.createStation(createDTO, adminId);
                    
                    results.add(CsvImportResponseDTO.ImportResult.builder()
                            .rowNumber(rowNumber)
                            .stationName(row.name)
                            .success(true)
                            .stationId(created.getStationId().toString())
                            .build());
                    
                    log.info("Imported station from row {}: {}", rowNumber, row.name);
                    
                } catch (Exception e) {
                    log.error("Failed to import station from row {}: {}", rowNumber, e.getMessage(), e);
                    
                    String stationName = "Unknown";
                    try {
                        CsvStationRow tempRow = parseCsvLine(line);
                        stationName = tempRow.name != null ? tempRow.name : "Unknown";
                    } catch (Exception ignored) {
                        // Use default
                    }
                    
                    results.add(CsvImportResponseDTO.ImportResult.builder()
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
        
        int successCount = (int) results.stream().filter(CsvImportResponseDTO.ImportResult::isSuccess).count();
        int failureCount = results.size() - successCount;
        
        return CsvImportResponseDTO.builder()
                .totalRows(rowNumber - 1) // Exclude header
                .successCount(successCount)
                .failureCount(failureCount)
                .results(results)
                .build();
    }
    
    private CsvStationRow parseCsvLine(String line) {
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
        
        if (fields.size() < 16) {
            throw new IllegalArgumentException("Invalid CSV row: expected 16 columns, got " + fields.size());
        }
        
        CsvStationRow row = new CsvStationRow();
        row.name = fields.get(0);
        row.address = fields.get(1);
        row.latitude = parseDouble(fields.get(2));
        row.longitude = parseDouble(fields.get(3));
        row.ports250kw = parseInt(fields.get(4));
        row.ports180kw = parseInt(fields.get(5));
        row.ports150kw = parseInt(fields.get(6));
        row.ports120kw = parseInt(fields.get(7));
        row.ports80kw = parseInt(fields.get(8));
        row.ports60kw = parseInt(fields.get(9));
        row.ports40kw = parseInt(fields.get(10));
        row.portsAc = parseInt(fields.get(11));
        row.operatingHours = fields.get(12);
        row.parking = fields.get(13);
        row.stationType = fields.get(14);
        row.status = fields.get(15);
        
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
    
    private int parseInt(String value) {
        if (value == null || value.trim().isEmpty()) {
            return 0;
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return 0;
        }
    }
    
    private CreateStationDTO convertToCreateDTO(CsvStationRow row) {
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
        
        // Build services with charging ports
        List<CreateStationDTO.ServiceDTO> services = new ArrayList<>();
        List<CreateStationDTO.ChargingPortDTO> chargingPorts = new ArrayList<>();
        
        // Add DC ports
        if (row.ports250kw > 0) {
            chargingPorts.add(createPortDTO(PowerType.DC, new BigDecimal("250"), row.ports250kw));
        }
        if (row.ports180kw > 0) {
            chargingPorts.add(createPortDTO(PowerType.DC, new BigDecimal("180"), row.ports180kw));
        }
        if (row.ports150kw > 0) {
            chargingPorts.add(createPortDTO(PowerType.DC, new BigDecimal("150"), row.ports150kw));
        }
        if (row.ports120kw > 0) {
            chargingPorts.add(createPortDTO(PowerType.DC, new BigDecimal("120"), row.ports120kw));
        }
        if (row.ports80kw > 0) {
            chargingPorts.add(createPortDTO(PowerType.DC, new BigDecimal("80"), row.ports80kw));
        }
        if (row.ports60kw > 0) {
            chargingPorts.add(createPortDTO(PowerType.DC, new BigDecimal("60"), row.ports60kw));
        }
        if (row.ports40kw > 0) {
            chargingPorts.add(createPortDTO(PowerType.DC, new BigDecimal("40"), row.ports40kw));
        }
        
        // Add AC ports
        if (row.portsAc > 0) {
            chargingPorts.add(createPortDTO(PowerType.AC, null, row.portsAc));
        }
        
        if (chargingPorts.isEmpty()) {
            throw new IllegalArgumentException("At least one charging port is required");
        }
        
        CreateStationDTO.ServiceDTO service = new CreateStationDTO.ServiceDTO();
        service.setType(ServiceType.CHARGING);
        service.setChargingPorts(chargingPorts);
        services.add(service);
        
        // Build station data
        CreateStationDTO.StationDataDTO stationData = new CreateStationDTO.StationDataDTO();
        stationData.setName(row.name);
        stationData.setAddress(row.address);
        
        CreateStationDTO.LocationDTO location = new CreateStationDTO.LocationDTO();
        location.setLat(row.latitude);
        location.setLng(row.longitude);
        stationData.setLocation(location);
        
        stationData.setOperatingHours(row.operatingHours);
        
        // Parse parking type
        ParkingType parkingType = parseParkingType(row.parking);
        stationData.setParking(parkingType);
        
        // Parse visibility type
        VisibilityType visibilityType = parseVisibilityType(row.stationType);
        stationData.setVisibility(visibilityType);
        
        // Parse public status
        PublicStatus publicStatus = parsePublicStatus(row.status);
        stationData.setPublicStatus(publicStatus);
        
        stationData.setServices(services);
        
        // Build create DTO
        CreateStationDTO createDTO = new CreateStationDTO();
        createDTO.setStationData(stationData);
        createDTO.setPublishImmediately(true); // Auto-publish imported stations
        
        return createDTO;
    }
    
    private CreateStationDTO.ChargingPortDTO createPortDTO(PowerType powerType, BigDecimal powerKw, int count) {
        CreateStationDTO.ChargingPortDTO port = new CreateStationDTO.ChargingPortDTO();
        port.setPowerType(powerType);
        port.setPowerKw(powerKw);
        port.setCount(count);
        return port;
    }
    
    private ParkingType parseParkingType(String value) {
        if (value == null) return ParkingType.UNKNOWN;
        String upper = value.toUpperCase().trim();
        if (upper.contains("PAID")) return ParkingType.PAID;
        if (upper.contains("FREE")) return ParkingType.FREE;
        return ParkingType.UNKNOWN;
    }
    
    private VisibilityType parseVisibilityType(String value) {
        if (value == null) return VisibilityType.PUBLIC;
        String upper = value.toUpperCase().trim();
        if (upper.contains("PRIVATE")) return VisibilityType.PRIVATE;
        if (upper.contains("RESTRICTED")) return VisibilityType.RESTRICTED;
        return VisibilityType.PUBLIC;
    }
    
    private PublicStatus parsePublicStatus(String value) {
        if (value == null) return PublicStatus.ACTIVE;
        String upper = value.toUpperCase().trim();
        if (upper.contains("INACTIVE")) return PublicStatus.INACTIVE;
        if (upper.contains("MAINTENANCE")) return PublicStatus.MAINTENANCE;
        return PublicStatus.ACTIVE;
    }
    
    // Helper class for CSV row
    private static class CsvStationRow {
        String name;
        String address;
        Double latitude;
        Double longitude;
        int ports250kw;
        int ports180kw;
        int ports150kw;
        int ports120kw;
        int ports80kw;
        int ports60kw;
        int ports40kw;
        int portsAc;
        String operatingHours;
        String parking;
        String stationType;
        String status;
    }
}

