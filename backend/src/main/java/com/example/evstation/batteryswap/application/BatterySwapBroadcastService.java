package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

/**
 * Central broadcast facade for battery swap real-time events.
 *
 * Routing:
 * - broadcastSlotUpdate  → both auth WS (EV user app) AND display WS (simulator)
 * - broadcastSwapCode   → display WS only (station display screen)
 * - broadcastSwapCompleted → both auth WS and display WS
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BatterySwapBroadcastService {

    private final BatterySwapWebSocketHandler authHandler;
    private final SimulatorDisplayWebSocketHandler displayHandler;

    public void broadcastSlotUpdate(UUID stationId, BatterySlotEntity slot) {
        try {
            authHandler.broadcastSlotUpdate(stationId, slot);
        } catch (Exception e) {
            log.warn("[Broadcast] auth broadcast failed: {}", e.getMessage());
        }
        try {
            displayHandler.broadcastSlotUpdate(stationId, slot);
        } catch (Exception e) {
            log.warn("[Broadcast] display broadcast failed: {}", e.getMessage());
        }
    }

    /**
     * Broadcast swap code ONLY to the simulator display screen (public WebSocket).
     * Does NOT send to the authenticated EV-user app WebSocket, because the user
     * sees the code on the physical station display and manually enters it in the app.
     */
    public void broadcastSwapCode(UUID stationId, UUID slotId, String swapCode,
                                  Instant deadline, UUID pileId, UUID targetSlotId) {
        try {
            displayHandler.broadcastSwapCode(stationId, slotId, swapCode, deadline, pileId, targetSlotId);
        } catch (Exception e) {
            log.warn("[Broadcast] display swap code broadcast failed: {}", e.getMessage());
        }
    }

    public void broadcastSwapCompleted(UUID stationId, UUID slotId, String status) {
        try {
            authHandler.broadcastSwapCompleted(stationId, slotId, status);
        } catch (Exception e) {
            log.warn("[Broadcast] auth swap completed broadcast failed: {}", e.getMessage());
        }
        try {
            displayHandler.broadcastSwapCompleted(stationId, slotId, status);
        } catch (Exception e) {
            log.warn("[Broadcast] display swap completed broadcast failed: {}", e.getMessage());
        }
    }
}
