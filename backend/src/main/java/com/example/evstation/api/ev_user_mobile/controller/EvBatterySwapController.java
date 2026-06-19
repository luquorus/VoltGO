package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.*;
import com.example.evstation.batteryswap.application.BatterySwapService;
import com.example.evstation.batteryswap.application.BatterySwapStationAdminService;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationListDTO;
import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.batteryswap.application.SwapCodeService;
import com.example.evstation.batteryswap.application.SwapSessionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Tag(name = "EV Battery Swap", description = "Dat va theo doi pin tai tram")
@RestController
@RequestMapping("/api/ev/battery-swap")
@RequiredArgsConstructor
public class EvBatterySwapController {

    private final BatterySwapService batterySwapService;
    private final SwapCodeService swapCodeService;
    private final SwapSessionService swapSessionService;
    private final BatterySwapStationAdminService batterySwapStationAdminService;

    @Operation(
            summary = "Search published battery-swap stations by name",
            description = "Search battery-swap stations whose published name matches the query. Used by EV user app for station auto-fill on UPDATE change requests. Mirrors the collab-mobile variant; uses the same admin service for behavior parity."
    )
    @GetMapping("/stations/search/by-name")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<PaginationResponse<BatterySwapStationListDTO>> searchBatterySwapStationsByName(
            @RequestParam String name,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        int safePage = Math.max(0, page);
        int safeSize = Math.min(Math.max(1, size), 50);
        PaginationResponse<BatterySwapStationListDTO> response = batterySwapStationAdminService
                .listStations(safePage, safeSize, name);
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "List nearby battery swap stations")
    @GetMapping("/stations")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<List<BatterySwapStationDTO>> getNearbyStations(
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(defaultValue = "15") double radiusKm) {
        return ResponseEntity.ok(batterySwapService.getNearbySwapStations(lat, lng, radiusKm));
    }

    @Operation(summary = "Get battery swap station detail with swap piles and slots")
    @GetMapping("/stations/{stationId}")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapStationDetailDTO> getStationDetail(
            @PathVariable UUID stationId) {
        return ResponseEntity.ok(batterySwapService.getStationDetail(stationId));
    }

    @Operation(summary = "Reserve a battery swap slot")
    @PostMapping("/reservations")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapReservationDTO> reserve(
            @Valid @RequestBody BatterySwapReserveRequestDTO request,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(batterySwapService.reserve(
                userId,
                request.getStationId(),
                request.getExpectedArrivalAt(),
                request.getRequestedBatteryPercent(),
                request.getBatteryCapacityKwh(),
                request.getPileId(),
                request.getSlotId(),
                request.getNote()));
    }

    @Operation(summary = "Confirm user has arrived at the station")
    @PostMapping("/reservations/{id}/confirm-arrival")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapReservationDTO> confirmArrival(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(batterySwapService.confirmArrival(userId, id));
    }

    /**
     * Start swap: validates conditions, generates swap code, broadcasts to simulator,
     * and transitions status to SWAPPING. Returns the reservation with the swap code.
     * User then waits for simulator to confirm completion.
     */
    @Operation(summary = "Start swap and get swap code (Flow 2: code required)")
    @PostMapping("/reservations/{id}/start")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapReservationDTO> startSwap(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(batterySwapService.startAndGenerateCode(userId, id));
    }

    @Operation(summary = "Simulate payment for a battery swap reservation")
    @PostMapping("/reservations/{id}/pay")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapReservationDTO> pay(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(batterySwapService.pay(userId, id));
    }

    @Operation(summary = "Cancel battery swap reservation")
    @PostMapping("/reservations/{id}/cancel")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapReservationDTO> cancel(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(batterySwapService.cancel(userId, id));
    }

    @Operation(summary = "List my battery swap reservations")
    @GetMapping("/reservations/mine")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<List<BatterySwapReservationDTO>> myReservations(Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(batterySwapService.getMyReservations(userId));
    }

    @Operation(summary = "Get reservation detail")
    @GetMapping("/reservations/{id}")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<BatterySwapReservationDTO> getReservation(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(batterySwapService.getReservation(userId, id));
    }

    @Operation(summary = "Get my active swap code for a reservation")
    @GetMapping("/reservations/{id}/swap-code")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<SwapCodeDTO> getSwapCode(
            @PathVariable UUID id,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(swapCodeService.getSwapCode(id, userId));
    }

    @Operation(summary = "Verify swap code and confirm swap (called by user app)")
    @PostMapping("/reservations/{id}/verify-swap")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<SwapSessionDTO> verifySwap(
            @PathVariable UUID id,
            @Valid @RequestBody SwapVerifyRequestDTO request,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(swapSessionService.confirmSwapCompletion(
                id, userId, request.getSwapCode()));
    }

    @Operation(summary = "Get charging session info for a slot")
    @GetMapping("/slots/{slotId}/charging")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<ChargingSessionDTO> getSlotChargingSession(@PathVariable UUID slotId) {
        ChargingSessionDTO session = swapSessionService.getSlotChargingSession(slotId);
        if (session == null) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(session);
    }
}
