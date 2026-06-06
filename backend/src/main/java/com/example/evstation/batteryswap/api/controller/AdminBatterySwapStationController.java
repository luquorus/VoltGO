package com.example.evstation.batteryswap.api.controller;

import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationDetailDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationListDTO;
import com.example.evstation.batteryswap.api.dto.UpdateBatterySwapStationDTO;
import com.example.evstation.batteryswap.application.BatterySwapStationAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@Tag(name = "Admin Battery Swap Stations", description = "Admin API for battery swap station management")
@RestController
@RequestMapping("/api/admin/battery-swap/stations")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminBatterySwapStationController {

    private final BatterySwapStationAdminService service;

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
