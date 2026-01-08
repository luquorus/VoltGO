package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.admin_web.dto.StationTrustDTO;
import com.example.evstation.trust.application.TrustScoringService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@Tag(name = "Admin Stations", description = "Admin API for station management")
@RestController
@RequestMapping("/api/admin/stations")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminStationController {
    
    private final TrustScoringService trustScoringService;

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
}

