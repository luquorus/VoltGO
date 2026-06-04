package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.RouteRequestDTO;
import com.example.evstation.api.ev_user_mobile.dto.RouteResponseDTO;
import com.example.evstation.api.ev_user_mobile.service.RoutingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/ev/routing")
@PreAuthorize("hasRole('EV_USER')")
@Tag(name = "EV Routing", description = "Route calculation and charging station recommendations")
public class RoutingController {

    private final RoutingService routingService;

    @PostMapping("/route")
    @Operation(
        summary = "Calculate route with charging station recommendations",
        description = "Calculate optimal route between origin and destination, " +
                      "returning the route polyline and recommended charging stations along the way. " +
                      "Performs EV-aware routing when battery information is provided."
    )
    public ResponseEntity<RouteResponseDTO> calculateRoute(
            @Valid @RequestBody RouteRequestDTO request) {

        log.info("[ROUTING] POST /api/ev/routing/route | origin=({},{}) destination=({},{}) "
                        + "| battery={}% vehicleRange={}km",
                request.getOrigin().getLat(), request.getOrigin().getLng(),
                request.getDestination().getLat(), request.getDestination().getLng(),
                request.getBatteryPercent(), request.getVehicleRangeKm());

        RouteResponseDTO response = routingService.calculateRoute(request);

        log.info("[ROUTING] Response | distance={}m duration={}s polylinePoints={} "
                        + "stations={} needsChargingStop={} optimalStation={}",
                response.getDistanceMeters(),
                response.getDurationSeconds(),
                response.getPolyline() != null ? response.getPolyline().size() : 0,
                response.getRecommendedStations() != null ? response.getRecommendedStations().size() : 0,
                response.getNeedsChargingStop(),
                response.getOptimalStation() != null
                        ? response.getOptimalStation().getStationId() : "none");

        return ResponseEntity.ok(response);
    }
}
