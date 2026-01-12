package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.RecommendationRequestDTO;
import com.example.evstation.api.ev_user_mobile.dto.RecommendationResponseDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationListItemDTO;
import com.example.evstation.common.web.PaginationRequest;
import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.station.application.RecommendationQueryService;
import com.example.evstation.station.application.StationQueryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.UUID;

@Slf4j
@Tag(name = "EV User Mobile", description = "API for EV User Mobile application")
@RestController
@RequestMapping("/api/ev")
@RequiredArgsConstructor
public class EvUserMobileController {
    
    private final StationQueryService stationQueryService;
    private final RecommendationQueryService recommendationQueryService;

    @Operation(
        summary = "Search published stations within radius",
        description = "Find published charging stations within specified radius. Only returns PUBLISHED versions."
    )
    @GetMapping("/stations")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<PaginationResponse<StationListItemDTO>> searchStations(
            @Parameter(description = "Latitude", required = true)
            @RequestParam @NotNull @DecimalMin(value = "-90") @DecimalMax(value = "90") Double lat,
            
            @Parameter(description = "Longitude", required = true)
            @RequestParam @NotNull @DecimalMin(value = "-180") @DecimalMax(value = "180") Double lng,
            
            @Parameter(description = "Radius in kilometers", required = true)
            @RequestParam @NotNull @DecimalMin(value = "0.1") @DecimalMax(value = "100") Double radiusKm,
            
            @Parameter(description = "Minimum power in kW (DC ports only)")
            @RequestParam(required = false) BigDecimal minPowerKw,
            
            @Parameter(description = "Filter stations that have AC ports")
            @RequestParam(required = false) Boolean hasAC,
            
            PaginationRequest pagination) {
        
        Page<StationListItemDTO> page = stationQueryService.findStationsWithinRadius(
                lat, lng, radiusKm, minPowerKw, hasAC, pagination.toPageable()
        );
        
        return ResponseEntity.ok(PaginationResponse.fromPage(page));
    }

    @Operation(
        summary = "Get published station detail",
        description = "Get full detail of a published station including all charging ports"
    )
    @GetMapping("/stations/{stationId}")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<StationDetailDTO> getStationDetail(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {
        
        // Debug logging
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null) {
            log.debug("getStationDetail: stationId={}, authenticated={}, authorities={}", 
                    stationId, auth.isAuthenticated(), auth.getAuthorities());
        } else {
            log.warn("getStationDetail: stationId={}, authentication is null", stationId);
        }
        
        return stationQueryService.findStationDetail(stationId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
        summary = "Search published stations by name",
        description = "Search published charging stations by name (case-insensitive, partial match). Only returns PUBLISHED versions."
    )
    @GetMapping("/stations/search/by-name")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<PaginationResponse<StationListItemDTO>> searchStationsByName(
            @Parameter(description = "Search query for station name", required = true)
            @RequestParam @NotNull String name,
            
            PaginationRequest pagination) {
        
        Page<StationListItemDTO> page = stationQueryService.searchStationsByName(
                name, pagination.toPageable()
        );
        
        return ResponseEntity.ok(PaginationResponse.fromPage(page));
    }

    @Operation(
        summary = "Get station recommendations",
        description = "Get optimal station recommendations based on battery level, capacity, and target charge level. Optimizes for minimum total time (travel + charging)."
    )
    @PostMapping("/stations/recommendations")
    @PreAuthorize("hasRole('EV_USER') or hasRole('PROVIDER')")
    public ResponseEntity<RecommendationResponseDTO> getRecommendations(
            @RequestBody @jakarta.validation.Valid RecommendationRequestDTO request) {
        
        RecommendationResponseDTO response = recommendationQueryService.getRecommendations(request);
        return ResponseEntity.ok(response);
    }
}

