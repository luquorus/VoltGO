package com.example.evstation.notification.application;

import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.common.infrastructure.email.EmailService;
import com.example.evstation.notification.api.dto.EvUserNotificationDTO;
import com.example.evstation.notification.api.dto.EvUserNotificationPageDTO;
import com.example.evstation.notification.domain.EvUserNotificationCategory;
import com.example.evstation.notification.domain.EvUserNotificationType;
import com.example.evstation.notification.infrastructure.jpa.EvUserNotificationEntity;
import com.example.evstation.notification.infrastructure.jpa.EvUserNotificationJpaRepository;
import com.example.evstation.notification.infrastructure.push.FCMService;
import com.example.evstation.notification.api.dto.PushPayload;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class EvUserNotificationService {

    private final EvUserNotificationJpaRepository notificationRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final EmailService emailService;
    private final FCMService fcmService;
    private final ObjectMapper objectMapper;

    // --- Send notification ---

    @Transactional
    public void send(UUID recipientId, EvUserNotificationType type, String title, String body,
                    Map<String, Object> data, UUID referenceId, String referenceType) {
        EvUserNotificationCategory category = type.getCategory();
        String dataJson = serializeData(data);

        EvUserNotificationEntity entity = EvUserNotificationEntity.builder()
                .recipientId(recipientId)
                .type(type)
                .category(category)
                .title(title)
                .body(body)
                .dataJson(dataJson)
                .referenceId(referenceId)
                .referenceType(referenceType)
                .isRead(false)
                .build();
        notificationRepository.save(entity);

        // Send push and email asynchronously
        sendPushNotification(recipientId, type, title, body, data);
        sendEmailNotification(recipientId, title, body);
    }

    // --- Send notification to multiple users ---

    @Transactional
    public void sendToUsers(List<UUID> recipientIds, EvUserNotificationType type,
                            String title, String body, Map<String, Object> data,
                            UUID referenceId, String referenceType) {
        for (UUID recipientId : recipientIds) {
            send(recipientId, type, title, body, data, referenceId, referenceType);
        }
    }

    // --- Send push notification ---

    @Async
    public void sendPushNotification(UUID recipientId, EvUserNotificationType type,
                                    String title, String body, Map<String, Object> data) {
        try {
            Map<String, Object> payload = new java.util.HashMap<>();
            payload.put("type", type.name());
            payload.put("title", title);
            payload.put("body", body);
            payload.put("data", data);
            fcmService.sendToUser(recipientId.toString(), payload);
        } catch (Exception e) {
            log.error("Failed to send push notification to {}: {}", recipientId, e.getMessage());
        }
    }

    // --- Send email notification ---

    @Async
    public void sendEmailNotification(UUID recipientId, String subject, String body) {
        try {
            String email = userAccountRepository.findById(recipientId)
                    .map(u -> u.getEmail())
                    .orElse(null);
            if (email == null) {
                log.warn("No email found for user {}", recipientId);
                return;
            }

            emailService.sendEmail(email, subject, body);
        } catch (Exception e) {
            log.error("Failed to send email notification to {}: {}", recipientId, e.getMessage());
        }
    }

    // --- Get notifications (paginated) ---

    @Transactional(readOnly = true)
    public EvUserNotificationPageDTO getNotifications(UUID recipientId, String category, Boolean isRead,
                                                      int page, int size) {
        Page<EvUserNotificationEntity> result;

        EvUserNotificationCategory cat = null;
        if (category != null && !category.isBlank() && !"ALL".equalsIgnoreCase(category)) {
            try {
                cat = EvUserNotificationCategory.valueOf(category.toUpperCase());
            } catch (IllegalArgumentException e) {
                // Invalid category, ignore filter
                log.warn("Invalid notification category: {}", category);
            }
        }

        if (cat != null && isRead != null) {
            result = notificationRepository.findByRecipientIdAndCategoryAndIsReadOrderByCreatedAtDesc(
                    recipientId, cat, isRead, PageRequest.of(page, size));
        } else if (cat != null) {
            result = notificationRepository.findByRecipientIdAndCategoryOrderByCreatedAtDesc(
                    recipientId, cat, PageRequest.of(page, size));
        } else if (isRead != null) {
            result = notificationRepository.findByRecipientIdAndIsReadOrderByCreatedAtDesc(
                    recipientId, isRead, PageRequest.of(page, size));
        } else {
            result = notificationRepository.findByRecipientIdOrderByCreatedAtDesc(
                    recipientId, PageRequest.of(page, size));
        }

        long unreadCount = notificationRepository.countByRecipientIdAndIsRead(recipientId, false);

        List<EvUserNotificationDTO> dtos = result.getContent().stream()
                .map(this::toDTO)
                .toList();

        return EvUserNotificationPageDTO.builder()
                .notifications(dtos)
                .totalElements(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .page(page)
                .size(size)
                .unreadCount(unreadCount)
                .build();
    }

    // --- Get unread count ---

    @Transactional(readOnly = true)
    public long getUnreadCount(UUID recipientId) {
        return notificationRepository.countByRecipientIdAndIsRead(recipientId, false);
    }

    // --- Mark as read ---

    @Transactional
    public void markAsRead(UUID notificationId, UUID recipientId) {
        int updated = notificationRepository.markAsRead(notificationId, recipientId);
        if (updated == 0) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "Notification not found");
        }
    }

    @Transactional
    public void markAllAsRead(UUID recipientId) {
        notificationRepository.markAllAsRead(recipientId);
    }

    // --- Helpers ---

    private EvUserNotificationDTO toDTO(EvUserNotificationEntity entity) {
        return EvUserNotificationDTO.builder()
                .id(entity.getId())
                .type(entity.getType())
                .category(entity.getCategory())
                .title(entity.getTitle())
                .body(entity.getBody())
                .data(deserializeData(entity.getDataJson()))
                .isRead(entity.getIsRead())
                .referenceId(entity.getReferenceId())
                .referenceType(entity.getReferenceType())
                .createdAt(entity.getCreatedAt())
                .build();
    }

    private String serializeData(Map<String, Object> data) {
        if (data == null || data.isEmpty()) return null;
        try {
            return objectMapper.writeValueAsString(data);
        } catch (JsonProcessingException e) {
            log.warn("Failed to serialize notification data: {}", e.getMessage());
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> deserializeData(String json) {
        if (json == null || json.isBlank()) return null;
        try {
            return objectMapper.readValue(json, Map.class);
        } catch (JsonProcessingException e) {
            log.warn("Failed to deserialize notification data: {}", e.getMessage());
            return null;
        }
    }
}
