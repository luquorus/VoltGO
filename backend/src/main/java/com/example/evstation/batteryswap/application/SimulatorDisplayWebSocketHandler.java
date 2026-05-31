package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.StationDeviceJpaRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Public WebSocket handler for the battery swap station display screen.
 * Accepts connections with deviceKey query param for device authentication.
 * Broadcasts swap codes and slot updates in real-time.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SimulatorDisplayWebSocketHandler extends TextWebSocketHandler {

    private final ObjectMapper objectMapper;
    private final SwapPileJpaRepository swapPileRepository;
    private final StationDeviceJpaRepository stationDeviceRepository;

    /** stationId -> Set<WebSocketSession> */
    private final Map<String, Set<WebSocketSession>> stationSubscriptions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(@NotNull WebSocketSession session) throws Exception {
        String query = session.getUri() != null ? session.getUri().getQuery() : "";
        String deviceKey = extractDeviceKey(query);

        // Optional: if deviceKey is provided, validate it
        if (deviceKey != null && !deviceKey.isBlank()) {
            UUID stationId = stationDeviceRepository.findByDeviceKey(deviceKey)
                    .map(d -> {
                        d.setLastSeenAt(Instant.now());
                        stationDeviceRepository.save(d);
                        return d.getStationId();
                    })
                    .orElse(null);
            if (stationId != null) {
                log.info("[DisplayWS] Client connected with device key: sessionId={}, stationId={}", session.getId(), stationId);
            } else {
                log.warn("[DisplayWS] Invalid device key: sessionId={}", session.getId());
            }
        } else {
            log.info("[DisplayWS] Client connected (no device key): sessionId={}", session.getId());
        }

        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(Map.of(
                "type", "CONNECTED"
        ))));
    }

    private String extractDeviceKey(String query) {
        if (query == null || query.isBlank()) return null;
        for (String param : query.split("&")) {
            String[] kv = param.split("=", 2);
            if (kv.length == 2 && "deviceKey".equals(kv[0])) {
                return kv[1];
            }
        }
        return null;
    }

    @Override
    protected void handleTextMessage(@NotNull WebSocketSession session, @NotNull TextMessage message) throws Exception {
        try {
            Map<String, Object> payload = objectMapper.readValue(message.getPayload(), Map.class);
            String type = (String) payload.get("type");

            switch (type) {
                case "subscribe" -> handleSubscribe(session, (String) payload.get("stationId"));
                case "unsubscribe" -> handleUnsubscribe(session, (String) payload.get("stationId"));
                default -> sendError(session, "Unknown message type: " + type);
            }
        } catch (Exception e) {
            log.warn("[DisplayWS] Invalid message from session {}: {}", session.getId(), e.getMessage());
            sendError(session, "Invalid message format");
        }
    }

    @Override
    public void afterConnectionClosed(@NotNull WebSocketSession session, @NotNull CloseStatus status) throws Exception {
        stationSubscriptions.values().forEach(set -> set.remove(session));
        log.info("[DisplayWS] Client disconnected: sessionId={}", session.getId());
    }

    /**
     * Broadcast slot update to all display sessions subscribed to the station.
     */
    public void broadcastSlotUpdate(UUID stationId, BatterySlotEntity slot) {
        String stationIdStr = stationId.toString();
        Set<WebSocketSession> sessions = stationSubscriptions.get(stationIdStr);
        if (sessions == null || sessions.isEmpty()) return;

        Instant now = Instant.now();

        Map<String, Object> update = Map.of(
                "type", "SLOT_UPDATE",
                "stationId", stationIdStr,
                "slot", Map.of(
                        "slotId", slot.getId().toString(),
                        "slotIndex", slot.getSlotIndex(),
                        "batteryId", slot.getBatteryId() != null ? slot.getBatteryId().toString() : null,
                        "batteryChargePercent", slot.getBatteryChargePercent(),
                        "status", slot.getStatus().name(),
                        "estimatedFullAt", slot.getEstimatedFullAt() != null ? slot.getEstimatedFullAt().toString() : null,
                        "updatedAt", now.toString()
                )
        );

        broadcast(stationIdStr, update);
    }

    /**
     * Broadcast swap code to all display sessions subscribed to the station.
     */
    public void broadcastSwapCode(UUID stationId, UUID slotId, String swapCode,
                                  Instant deadline, UUID pileId, UUID targetSlotId) {
        String stationIdStr = stationId.toString();

        Map<String, Object> update = Map.of(
                "type", "SWAP_CODE",
                "stationId", stationIdStr,
                "swapCode", swapCode,
                "slotId", slotId.toString(),
                "pileId", pileId.toString(),
                "deadlineAt", deadline != null ? deadline.toString() : null
        );

        broadcast(stationIdStr, update);
        log.info("[DisplayWS] Broadcast SWAP_CODE {} to station {} (slot={}, deadline={})",
                swapCode, stationIdStr, slotId, deadline);
    }

    /**
     * Broadcast swap completion to all display sessions subscribed to the station.
     */
    public void broadcastSwapCompleted(UUID stationId, UUID slotId, String status) {
        String stationIdStr = stationId.toString();

        Map<String, Object> update = Map.of(
                "type", "SWAP_COMPLETED",
                "stationId", stationIdStr,
                "slotId", slotId.toString(),
                "newStatus", status
        );

        broadcast(stationIdStr, update);
    }

    private void broadcast(String stationId, Map<String, Object> payload) {
        Set<WebSocketSession> sessions = stationSubscriptions.get(stationId);
        if (sessions == null || sessions.isEmpty()) return;

        String json;
        try {
            json = objectMapper.writeValueAsString(payload);
        } catch (Exception e) {
            log.error("[DisplayWS] Failed to serialize broadcast", e);
            return;
        }

        for (WebSocketSession s : List.copyOf(sessions)) {
            try {
                if (s.isOpen()) {
                    s.sendMessage(new TextMessage(json));
                }
            } catch (IOException e) {
                log.warn("[DisplayWS] Failed to send to session {}: {}", s.getId(), e.getMessage());
                sessions.remove(s);
            }
        }
    }

    private void handleSubscribe(WebSocketSession session, String stationId) throws IOException {
        if (stationId == null || stationId.isBlank()) {
            sendError(session, "stationId is required for subscribe");
            return;
        }
        stationSubscriptions
                .computeIfAbsent(stationId, k -> ConcurrentHashMap.newKeySet())
                .add(session);
        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(Map.of(
                "type", "SUBSCRIBED",
                "stationId", stationId
        ))));
        log.debug("[DisplayWS] Session {} subscribed to station {}", session.getId(), stationId);
    }

    private void handleUnsubscribe(WebSocketSession session, String stationId) {
        if (stationId == null) return;
        Set<WebSocketSession> set = stationSubscriptions.get(stationId);
        if (set != null) {
            set.remove(session);
            if (set.isEmpty()) {
                stationSubscriptions.remove(stationId);
            }
        }
    }

    private void sendError(WebSocketSession session, String message) {
        try {
            session.sendMessage(new TextMessage(objectMapper.writeValueAsString(Map.of(
                    "type", "ERROR",
                    "message", message
            ))));
        } catch (IOException ignored) {}
    }
}
