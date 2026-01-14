package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.admin_web.dto.*;
import com.example.evstation.common.web.PaginationRequest;
import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.station.application.AdminStationService;
import com.example.evstation.station.application.CsvImportService;
import com.example.evstation.trust.application.TrustScoringService;
import org.springframework.web.multipart.MultipartFile;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@Tag(name = "Admin Stations", description = "Admin API for station management")
@RestController
@RequestMapping("/api/admin/stations")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminStationController {
    
    private final AdminStationService adminStationService;
    private final CsvImportService csvImportService;
    private final TrustScoringService trustScoringService;
    
    private UUID extractUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }

    @Operation(
        summary = "List all stations",
        description = "Get paginated list of all stations (admin only)"
    )
    @GetMapping
    public ResponseEntity<PaginationResponse<AdminStationDTO>> getAllStations(
            PaginationRequest pagination) {
        
        log.info("Admin getting all stations: page={}, size={}", pagination.getPage(), pagination.getSize());
        
        Page<AdminStationDTO> page = adminStationService.getAllStations(pagination.toPageable());
        return ResponseEntity.ok(PaginationResponse.fromPage(page));
    }
    
    @Operation(
        summary = "Get station detail",
        description = "Get full details of a station including all versions (admin only)"
    )
    @GetMapping("/{stationId}")
    public ResponseEntity<AdminStationDTO> getStation(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {
        
        log.info("Admin getting station: {}", stationId);
        
        return adminStationService.getStationById(stationId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @Operation(
        summary = "Create new station",
        description = "Create a new station directly (bypass change request workflow). Admin only."
    )
    @PostMapping
    public ResponseEntity<AdminStationDTO> createStation(
            @Valid @RequestBody CreateStationDTO request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        log.info("Admin creating station: name={}, adminId={}", request.getStationData().getName(), adminId);
        
        AdminStationDTO response = adminStationService.createStation(request, adminId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
    
    @Operation(
        summary = "Update station",
        description = "Update a station by creating a new version. Admin only."
    )
    @PutMapping("/{stationId}")
    public ResponseEntity<AdminStationDTO> updateStation(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId,
            @Valid @RequestBody UpdateStationDTO request,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        log.info("Admin updating station: {}, adminId={}", stationId, adminId);
        
        AdminStationDTO response = adminStationService.updateStation(stationId, request, adminId);
        return ResponseEntity.ok(response);
    }
    
    @Operation(
        summary = "Delete station",
        description = "Permanently delete a station from database. All related data (versions, services, ports, bookings, etc.) will be automatically deleted due to CASCADE constraints. Cannot delete if there are active bookings."
    )
    @DeleteMapping("/{stationId}")
    public ResponseEntity<Void> deleteStation(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        log.info("Admin deleting station: {}, adminId={}", stationId, adminId);
        
        adminStationService.deleteStation(stationId, adminId);
        return ResponseEntity.noContent().build();
    }
    
    @Operation(
        summary = "Get station trust score breakdown",
        description = "Get full trust score with detailed breakdown for a station (admin only)"
    )
    @GetMapping("/{stationId}/trust")
    public ResponseEntity<StationTrustDTO> getStationTrust(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {
        
        log.info("Admin getting trust score for station: {}", stationId);
        
        return trustScoringService.getTrustEntity(stationId)
                .map(entity -> StationTrustDTO.builder()
                        .stationId(entity.getStationId().toString())
                        .score(entity.getScore())
                        .breakdown(entity.getBreakdown())
                        .updatedAt(entity.getUpdatedAt())
                        .build())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
        summary = "Recalculate station trust score",
        description = "Force recalculation of trust score for a station"
    )
    @PostMapping("/{stationId}/trust/recalculate")
    public ResponseEntity<StationTrustDTO> recalculateTrust(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {
        
        log.info("Admin forcing trust recalculation for station: {}", stationId);
        
        trustScoringService.recalculate(stationId);
        
        return trustScoringService.getTrustEntity(stationId)
                .map(entity -> StationTrustDTO.builder()
                        .stationId(entity.getStationId().toString())
                        .score(entity.getScore())
                        .breakdown(entity.getBreakdown())
                        .updatedAt(entity.getUpdatedAt())
                        .build())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @Operation(
        summary = "Import stations from CSV",
        description = "Import multiple stations from CSV file. Format: name,address,latitude,longitude,ports_250kw,ports_180kw,ports_150kw,ports_120kw,ports_80kw,ports_60kw,ports_40kw,ports_ac,operatingHours,parking,stationType,status"
    )
    @PostMapping(value = "/import-csv", consumes = "multipart/form-data")
    public ResponseEntity<CsvImportResponseDTO> importStationsFromCsv(
            @Parameter(description = "CSV file", required = true)
            @RequestParam("file") MultipartFile file,
            Authentication authentication) {
        
        UUID adminId = extractUserId(authentication);
        log.info("Admin importing stations from CSV: {}, adminId={}", file.getOriginalFilename(), adminId);
        
        if (file.isEmpty()) {
            return ResponseEntity.badRequest().build();
        }
        
        if (!file.getOriginalFilename().endsWith(".csv")) {
            return ResponseEntity.badRequest().build();
        }
        
        CsvImportResponseDTO response = csvImportService.importStations(file, adminId);
        return ResponseEntity.ok(response);
    }
}

