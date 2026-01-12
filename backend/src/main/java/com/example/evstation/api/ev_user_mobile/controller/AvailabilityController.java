package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.AvailabilityResponseDTO;
import com.example.evstation.booking.application.AvailabilityService;
import com.example.evstation.station.domain.PowerType;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Slf4j
@Tag(name = "Availability", description = "API for EV Users to check slot availability")
@RestController
@RequestMapping("/api/ev/stations")
@RequiredArgsConstructor
@PreAuthorize("hasRole('EV_USER')")
public class AvailabilityController {
    
    private final AvailabilityService availabilityService;
    
    @Operation(
        summary = "Get availability for a station",
        description = "Get slot availability matrix for charger units on a specific date"
    )
    @GetMapping("/{stationId}/availability")
    public ResponseEntity<AvailabilityResponseDTO> getAvailability(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId,
            
            @Parameter(description = "Date (YYYY-MM-DD)", required = true)
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            
            @Parameter(description = "Timezone (default: Asia/Bangkok)")
            @RequestParam(required = false, defaultValue = "Asia/Bangkok") String tz,
            
            @Parameter(description = "Slot duration in minutes (default: 30)")
            @RequestParam(required = false, defaultValue = "30") Integer slotMinutes,
            
            @Parameter(description = "Filter by power type (DC or AC)")
            @RequestParam(required = false) PowerType powerType,
            
            @Parameter(description = "Minimum power in kW")
            @RequestParam(required = false) BigDecimal minPowerKw) {
        
        log.debug("Getting availability: stationId={}, date={}, tz={}, slotMinutes={}", 
                stationId, date, tz, slotMinutes);
        
        AvailabilityResponseDTO response = availabilityService.getAvailability(
                stationId, date, tz, slotMinutes, powerType, minPowerKw);
        return ResponseEntity.ok(response);
    }
}

