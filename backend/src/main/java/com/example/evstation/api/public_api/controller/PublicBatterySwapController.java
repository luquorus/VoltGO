package com.example.evstation.api.public_api.controller;

import com.example.evstation.api.ev_user_mobile.dto.BatterySwapStationDTO;
import com.example.evstation.api.ev_user_mobile.dto.BatterySwapStationDetailDTO;
import com.example.evstation.api.public_api.dto.ActiveSwapCodeDTO;
import com.example.evstation.api.public_api.dto.StationPilesDTO;
import com.example.evstation.batteryswap.application.BatterySwapService;
import com.example.evstation.batteryswap.application.StationDeviceService;
import com.example.evstation.batteryswap.domain.SwapSessionStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapReservationJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapSessionJpaRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Tag(name = "Public Battery Swap Display", description = "Public API for battery swap station display (no auth)")
@RestController
@RequestMapping("/api/public")
@RequiredArgsConstructor
public class PublicBatterySwapController {

    private final BatterySwapService batterySwapService;
    private final StationDeviceService stationDeviceService;
    private final SwapSessionJpaRepository swapSessionRepository;
    private final BatterySwapReservationJpaRepository reservationRepository;

    @Operation(summary = "List all published battery swap stations")
    @GetMapping("/battery-swap/stations")
    public ResponseEntity<?> getAllStations() {
        return ResponseEntity.ok(batterySwapService.listAllSwapStations());
    }

    @Operation(summary = "Get station detail with piles and slots")
    @GetMapping("/battery-swap/stations/{stationId}")
    public ResponseEntity<?> getStationDetail(@PathVariable UUID stationId) {
        return ResponseEntity.ok(batterySwapService.getStationDetail(stationId));
    }

    @Operation(summary = "Get station piles and slots for display screen (hardware simulator)")
    @GetMapping("/battery-swap/stations/{stationId}/piles")
    public ResponseEntity<StationPilesDTO> getStationPiles(@PathVariable UUID stationId) {
        return ResponseEntity.ok(batterySwapService.getStationPiles(stationId));
    }

    @Operation(summary = "Get or register device key for a station (used by simulators/displays)")
    @GetMapping("/device/stations/{stationId}/key")
    public ResponseEntity<?> getDeviceKey(
            @PathVariable UUID stationId,
            @RequestParam(required = false) String deviceName) {
        String key = stationDeviceService.getOrCreateDeviceKey(stationId, deviceName);
        return ResponseEntity.ok(Map.of(
                "stationId", stationId,
                "deviceKey", key,
                "wsEndpoint", "/ws/display/battery-swap"
        ));
    }

    @Operation(summary = "Get current active (pending) swap code for a station — polling fallback")
    @GetMapping("/battery-swap/stations/{stationId}/active-code")
    public ResponseEntity<Object> getActiveSwapCode(@PathVariable UUID stationId) {
        var pending = swapSessionRepository
                .findByStatusOrderByCreatedAtDesc(SwapSessionStatus.PENDING)
                .stream()
                .filter(session -> {
                    var reservation = reservationRepository.findById(session.getReservationId()).orElse(null);
                    return reservation != null && reservation.getStationId().equals(stationId);
                })
                .findFirst();

        if (pending.isPresent()) {
            var session = pending.get();
            ActiveSwapCodeDTO dto = ActiveSwapCodeDTO.builder()
                    .swapCode(session.getSwapCode())
                    .deadlineAt(session.getExpiresAt())
                    .reservationId(session.getReservationId().toString())
                    .build();
            return ResponseEntity.ok(dto);
        }
        return ResponseEntity.ok(Map.of("swapCode", null));
    }
}
