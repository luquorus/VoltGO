package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.ChargerUnitDTO;
import com.example.evstation.booking.application.ChargerUnitService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Slf4j
@Tag(name = "Charger Units", description = "API for EV Users to view charger units")
@RestController
@RequestMapping("/api/ev/stations")
@RequiredArgsConstructor
@PreAuthorize("hasRole('EV_USER')")
public class ChargerUnitController {
    
    private final ChargerUnitService chargerUnitService;
    
    @Operation(
        summary = "Get charger units for a station",
        description = "Get all active charger units for a published station"
    )
    @GetMapping("/{stationId}/charger-units")
    public ResponseEntity<List<ChargerUnitDTO>> getChargerUnits(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {
        
        log.debug("Getting charger units for station: {}", stationId);
        List<ChargerUnitDTO> units = chargerUnitService.getChargerUnits(stationId);
        return ResponseEntity.ok(units);
    }
}

