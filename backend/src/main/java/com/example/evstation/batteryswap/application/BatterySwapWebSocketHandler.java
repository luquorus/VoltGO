package com.example.evstation.batteryswap.application;

import com.example.evstation.auth.application.port.JwtTokenProvider;
import com.example.evstation.batteryswap.domain.BatterySlotStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySlotJpaRepository;
import com.example.evstation.batteryswap.infrastructure.jpa.SwapPileJpaRepository;
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
 * WebSocket handler cho real-time battery swap slot updates.
 *
 * Flow:
 * 1. Client kết nối với JWT token trong query param: /ws/battery-swap?token=xxx
 * 2. Server xác thực token, extract userId, lưu session
 * 3. Client subscribe station: {"type":"subscribe","stationId":"uuid"}
 * 4. Server broadcast SLOT_UPDATE khi có pin thay đổi (qua BatterySlotSimulationJob)
 * 5. Client nhận update real-time, cập nhật UI
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BatterySwapWebSocketHandler extends TextWebSocketHandler {

    private final ObjectMapper objectMapper;
    private final JwtTokenProvider jwtTokenProvider;
    private final BatterySlotJpaRepository batterySlotRepository;
    private final SwapPileJpaRepository swapPileRepository;

    /** stationId → Set<WebSocketSession> */
    private final Map<String, Set<WebSocketSession>> stationSubscriptions = new ConcurrentHashMap<>();
    /** sessionId → userId */
    private final Map<String, String> sessionUserMap = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(@NotNull WebSocketSession session) throws Exception {
        String query = session.getUri() != null ? session.getUri().getQuery() : "";
        String token = extractToken(query);

        if (token == null) {
            rejectSession(session, "Missing or invalid token");
            return;
        }

        try {
            UUID userId = validateAndExtractUserId(token);
            sessionUserMap.put(session.getId(), userId.toString());
            session.sendMessage(new TextMessage(objectMapper.writeValueAsString(Map.of(
                    "type", "CONNECTED",
                    "userId", userId.toString()
            ))));
            log.info("[WS] Client connected: sessionId={}, userId={}", session.getId(), userId);
        } catch (Exception e) {
            rejectSession(session, "Authentication failed: " + e.getMessage());
        }
    }

    @Override
    protected void handleTextMessage(@NotNull WebSocketSession session, @NotNull TextMessage message) throws Exception {
        String userId = sessionUserMap.get(session.getId());
        if (userId == null) {
            sendError(session, "Not authenticated");
            return;
        }

        try {
            Map<String, Object> payload = objectMapper.readValue(message.getPayload(), Map.class);
            String type = (String) payload.get("type");

            switch (type) {
                case "subscribe" -> handleSubscribe(session, (String) payload.get("stationId"));
                case "unsubscribe" -> handleUnsubscribe(session, (String) payload.get("stationId"));
                default -> sendError(session, "Unknown message type: " + type);
            }
        } catch (Exception e) {
            log.warn("[WS] Invalid message from session {}: {}", session.getId(), e.getMessage());
            sendError(session, "Invalid message format");
        }
    }

    @Override
    public void afterConnectionClosed(@NotNull WebSocketSession session, @NotNull CloseStatus status) throws Exception {
        String userId = sessionUserMap.remove(session.getId());
        stationSubscriptions.values().forEach(set -> set.remove(session));
        log.info("[WS] Client disconnected: sessionId={}, userId={}, reason={}",
                session.getId(), userId, status);
    }

    /**
     * Broadcast slot update to all sessions subscribed to the station.
     * Called by BatterySlotSimulationJob after updating slot charge %.
     */
    public void broadcastSlotUpdate(UUID stationId, BatterySlotEntity slot) {
        String stationIdStr = stationId.toString();
        Set<WebSocketSession> sessions = stationSubscriptions.get(stationIdStr);
        if (sessions == null || sessions.isEmpty()) return;

        Instant now = Instant.now();
        Instant estimatedFullAt = slot.getEstimatedFullAt();

        Map<String, Object> update = Map.of(
                "type", "SLOT_UPDATE",
                "stationId", stationIdStr,
                "slot", Map.of(
                        "slotId", slot.getId().toString(),
                        "slotIndex", slot.getSlotIndex(),
                        "batteryId", slot.getBatteryId() != null ? slot.getBatteryId().toString() : null,
                        "batteryChargePercent", slot.getBatteryChargePercent(),
                        "status", slot.getStatus().name(),
                        "estimatedFullAt", estimatedFullAt != null ? estimatedFullAt.toString() : null,
                        "updatedAt", now.toString()
                )
        );

        String json;
        try {
            json = objectMapper.writeValueAsString(update);
        } catch (Exception e) {
            log.error("[WS] Failed to serialize slot update", e);
            return;
        }

        for (WebSocketSession s : List.copyOf(sessions)) {
            try {
                if (s.isOpen()) {
                    s.sendMessage(new TextMessage(json));
                }
            } catch (IOException e) {
                log.warn("[WS] Failed to send to session {}: {}", s.getId(), e.getMessage());
                sessions.remove(s);
            }
        }
    }

    /**
     * Broadcast swap completion to all sessions subscribed to the station.
     * Called when a swap is successfully completed.
     */
    public void broadcastSwapCompleted(UUID stationId, UUID slotId, String status) {
        String stationIdStr = stationId.toString();
        Set<WebSocketSession> sessions = stationSubscriptions.get(stationIdStr);
        if (sessions == null || sessions.isEmpty()) return;

        Map<String, Object> update = Map.of(
                "type", "SWAP_COMPLETED",
                "stationId", stationIdStr,
                "slotId", slotId.toString(),
                "newStatus", status
        );

        String json;
        try {
            json = objectMapper.writeValueAsString(update);
        } catch (Exception e) {
            log.error("[WS] Failed to serialize swap completed broadcast", e);
            return;
        }

        for (WebSocketSession s : List.copyOf(sessions)) {
            try {
                if (s.isOpen()) {
                    s.sendMessage(new TextMessage(json));
                }
            } catch (IOException e) {
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
        log.debug("[WS] Session {} subscribed to station {}", session.getId(), stationId);
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

    private UUID validateAndExtractUserId(String token) {
        JwtTokenProvider.TokenClaims claims = jwtTokenProvider.parseToken(token);
        return claims.userId();
    }

    private String extractToken(String query) {
        if (query == null || query.isBlank()) return null;
        for (String param : query.split("&")) {
            String[] kv = param.split("=", 2);
            if (kv.length == 2 && "token".equals(kv[0])) {
                return kv[1];
            }
        }
        return null;
    }

    private void rejectSession(WebSocketSession session, String reason) throws IOException {
        log.warn("[WS] Rejecting session: {}", reason);
        session.sendMessage(new TextMessage(objectMapper.writeValueAsString(Map.of(
                "type", "ERROR",
                "message", reason
        ))));
        session.close(CloseStatus.BAD_DATA);
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
