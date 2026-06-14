package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.RouteDebugDTO;
import com.example.evstation.api.ev_user_mobile.service.RoutingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/routing/debug")
@Profile({"dev", "staging"})
@Tag(name = "Routing Debug", description = "Diagnostic debug endpoints for routing (dev/staging only)")
public class RoutingDebugController {

    private final RoutingService routingService;

    @GetMapping("/stations-along-route")
    @Operation(
        summary = "Debug: stations along a route with diagnostic breakdown",
        description = "Returns detailed diagnostic info about stations along a route corridor. "
                      + "Only available in dev/staging profiles. "
                      + "Parameters: originLat, originLng, destLat, destLng, "
                      + "batteryPercent (optional), vehicleRangeKm (optional), bufferMeters (optional, default 5000)."
    )
    public ResponseEntity<RouteDebugDTO> debugStationsAlongRoute(
            @RequestParam double originLat,
            @RequestParam double originLng,
            @RequestParam double destLat,
            @RequestParam double destLng,
            @RequestParam(required = false) Integer batteryPercent,
            @RequestParam(required = false) Double vehicleRangeKm,
            @RequestParam(required = false) Integer bufferMeters) {

        log.info("[DEBUG_ENDPOINT] GET /api/v1/routing/debug/stations-along-route | "
                        + "origin=({},{}) dest=({},{}) batteryPercent={} vehicleRangeKm={} bufferMeters={}",
                originLat, originLng, destLat, destLng,
                batteryPercent, vehicleRangeKm, bufferMeters);

        RouteDebugDTO result = routingService.debugStationsAlongRoute(
                originLat, originLng, destLat, destLng,
                batteryPercent, vehicleRangeKm, bufferMeters);

        return ResponseEntity.ok(result);
    }
}
