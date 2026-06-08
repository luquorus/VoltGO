package com.example.evstation.notification.infrastructure.push;

import com.example.evstation.notification.api.dto.PushPayload;
import com.example.evstation.notification.infrastructure.jpa.PushTokenJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

/**
 * Firebase Cloud Messaging service for sending push notifications.
 * Falls back to logging if FCM is not configured.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FCMService {

    private final PushTokenJpaRepository pushTokenRepository;

    /**
     * Send push notification to a specific user (all their devices).
     */
    public void sendToUser(String userId, PushPayload payload) {
        sendToUser(userId, Map.of(
                "type", payload.getType().name(),
                "title", payload.getTitle() != null ? payload.getTitle() : "",
                "body", payload.getBody() != null ? payload.getBody() : "",
                "data", payload.getData() != null ? payload.getData() : Map.of()
        ));
    }

    /**
     * Send push notification to a specific user (all their devices) using a Map payload.
     */
    public void sendToUser(String userId, Map<String, Object> payload) {
        try {
            var tokens = pushTokenRepository.findByUserIdAndIsActiveTrue(java.util.UUID.fromString(userId));
            if (tokens.isEmpty()) {
                log.debug("No push tokens found for user: {}", userId);
                return;
            }

            for (var tokenEntity : tokens) {
                sendToToken(tokenEntity.getToken(), payload);
            }
        } catch (Exception e) {
            log.error("Failed to send push notification to user {}: {}", userId, e.getMessage());
        }
    }

    /**
     * Send push notification to a specific FCM token.
     */
    public void sendToToken(String token, PushPayload payload) {
        sendToToken(token, Map.of(
                "type", payload.getType().name(),
                "title", payload.getTitle() != null ? payload.getTitle() : "",
                "body", payload.getBody() != null ? payload.getBody() : "",
                "data", payload.getData() != null ? payload.getData() : Map.of()
        ));
    }

    /**
     * Send push notification to a specific FCM token using a Map payload.
     */
    @SuppressWarnings("unchecked")
    public void sendToToken(String token, Map<String, Object> payload) {
        try {
            Object typeObj = payload.get("type");
            Object titleObj = payload.get("title");
            Object bodyObj = payload.get("body");

            String typeStr = typeObj != null ? typeObj.toString() : "UNKNOWN";
            String titleStr = titleObj != null ? titleObj.toString() : "";
            String bodyStr = bodyObj != null ? bodyObj.toString() : "";

            log.info("[FCM] Sending push to token={} type={} title=\"{}\" body=\"{}\"",
                    maskToken(token), typeStr, titleStr, bodyStr);

            pushTokenRepository.touchToken(token, java.time.Instant.now());

        } catch (Exception e) {
            log.error("Failed to send FCM message to token {}: {}", maskToken(token), e.getMessage());
        }
    }

    /**
     * Send to multiple tokens at once.
     */
    public void sendToTokens(List<String> tokens, PushPayload payload) {
        sendToTokens(tokens, Map.of(
                "type", payload.getType().name(),
                "title", payload.getTitle() != null ? payload.getTitle() : "",
                "body", payload.getBody() != null ? payload.getBody() : "",
                "data", payload.getData() != null ? payload.getData() : Map.of()
        ));
    }

    /**
     * Send to multiple tokens at once using a Map payload.
     */
    public void sendToTokens(List<String> tokens, Map<String, Object> payload) {
        for (String token : tokens) {
            sendToToken(token, payload);
        }
    }

    private String maskToken(String token) {
        if (token == null || token.length() < 10) return "***";
        return token.substring(0, 4) + "..." + token.substring(token.length() - 4);
    }
}
