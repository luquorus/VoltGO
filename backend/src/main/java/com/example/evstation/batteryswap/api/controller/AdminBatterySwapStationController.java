package com.example.evstation.batteryswap.api.controller;

import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.batteryswap.api.dto.BatterySwapCsvImportResponseDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationDetailDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationListDTO;
import com.example.evstation.batteryswap.api.dto.CreateBatterySwapStationDTO;
import com.example.evstation.batteryswap.api.dto.UpdateBatterySwapStationDTO;
import com.example.evstation.batteryswap.application.BatterySwapCsvImportService;
import com.example.evstation.batteryswap.application.BatterySwapStationAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@Slf4j
@Tag(name = "Admin Battery Swap Stations", description = "Admin API for battery swap station management")
@RestController
@RequestMapping("/api/admin/battery-swap/stations")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminBatterySwapStationController {

    private final BatterySwapStationAdminService service;
    private final BatterySwapCsvImportService csvImportService;

    @Operation(
            summary = "List all battery swap stations",
            description = "Get paginated list of all battery swap stations with operational state."
    )
    @GetMapping
    public ResponseEntity<PaginationResponse<BatterySwapStationListDTO>> listStations(
            @Parameter(description = "Page number (0-based)")
            @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size")
            @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "Search by station name or ID")
            @RequestParam(required = false) String search) {

        log.info("Admin listing battery swap stations: page={}, size={}, search={}", page, size, search);
        PaginationResponse<BatterySwapStationListDTO> response = service.listStations(page, size, search);
        return ResponseEntity.ok(response);
    }

    @Operation(
            summary = "Get battery swap station detail",
            description = "Get full details of a battery swap station including pile layout."
    )
    @GetMapping("/{stationId}")
    public ResponseEntity<BatterySwapStationDetailDTO> getStation(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {

        log.info("Admin getting battery swap station: {}", stationId);
        return service.getStation(stationId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
            summary = "Create battery swap station",
            description = "Create a new battery swap station directly (admin bypass). Publishes immediately by default."
    )
    @PostMapping
    public ResponseEntity<BatterySwapStationDetailDTO> createStation(
            @Valid @RequestBody CreateBatterySwapStationDTO request,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        log.info("Admin creating battery swap station: name={}, publishImmediately={}",
                request.getStationData().getName(), request.getPublishImmediately());

        BatterySwapStationDetailDTO result = service.createStation(request, adminId);
        return ResponseEntity.status(HttpStatus.CREATED).body(result);
    }

    @Operation(
            summary = "Import battery swap stations from CSV",
            description = "Import multiple battery swap stations from CSV file. Format: name,address,latitude,longitude,totalBatteries,avgChargePowerKw,operatingHours,parkingFee,note. parkingFee and note are optional."
    )
    @PostMapping(value = "/import-csv", consumes = "multipart/form-data")
    public ResponseEntity<BatterySwapCsvImportResponseDTO> importStationsFromCsv(
            @Parameter(description = "CSV file", required = true)
            @RequestParam("file") MultipartFile file,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        log.info("Admin importing battery swap stations from CSV: {}, adminId={}", file.getOriginalFilename(), adminId);

        if (file.isEmpty()) {
            return ResponseEntity.badRequest().body(
                    BatterySwapCsvImportResponseDTO.builder()
                            .totalRows(0)
                            .successCount(0)
                            .failureCount(0)
                            .results(List.of())
                            .build());
        }

        if (!file.getOriginalFilename().endsWith(".csv")) {
            return ResponseEntity.badRequest().body(
                    BatterySwapCsvImportResponseDTO.builder()
                            .totalRows(0)
                            .successCount(0)
                            .failureCount(0)
                            .results(List.of())
                            .build());
        }

        try {
            BatterySwapCsvImportResponseDTO response = csvImportService.importStations(file, adminId);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            log.warn("CSV parsing error during import: {}", e.getMessage());
            return ResponseEntity.badRequest().body(
                    BatterySwapCsvImportResponseDTO.builder()
                            .totalRows(0)
                            .successCount(0)
                            .failureCount(0)
                            .results(List.of())
                            .build());
        }
    }

    @Operation(
            summary = "Update battery swap station",
            description = "Update a battery swap station directly (admin edit). Creates a new version, optionally publishing immediately."
    )
    @PutMapping("/{stationId}")
    public ResponseEntity<BatterySwapStationDetailDTO> updateStation(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId,
            @Valid @RequestBody UpdateBatterySwapStationDTO request,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        log.info("Admin updating battery swap station: {}, publishImmediately={}",
                stationId, request.getPublishImmediately());

        BatterySwapStationDetailDTO result = service.updateStation(stationId, request, adminId);
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Delete battery swap station",
            description = "Permanently delete a battery swap station and all its related data (change requests, versions, piles, state, trust). This action cannot be undone."
    )
    @DeleteMapping("/{stationId}")
    public ResponseEntity<Void> deleteStation(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId,
            Authentication authentication) {

        UUID adminId = extractUserId(authentication);
        log.info("Admin deleting battery swap station: {}, adminId={}", stationId, adminId);

        service.deleteStation(stationId, adminId);
        return ResponseEntity.noContent().build();
    }

    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
}
