package com.example.evstation.notification.application;

import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.common.infrastructure.email.EmailService;
import com.example.evstation.notification.api.dto.*;
import com.example.evstation.notification.domain.NotificationCategory;
import com.example.evstation.notification.domain.NotificationEvent;
import com.example.evstation.notification.domain.NotificationType;
import com.example.evstation.notification.infrastructure.jpa.CollaboratorNotificationJpaRepository;
import com.example.evstation.notification.infrastructure.jpa.CollaboratorNotificationEntity;
import com.example.evstation.notification.infrastructure.jpa.NotificationPreferenceJpaRepository;
import com.example.evstation.notification.infrastructure.jpa.NotificationPreferenceEntity;
import com.example.evstation.notification.infrastructure.jpa.PushTokenEntity;
import com.example.evstation.notification.infrastructure.jpa.PushTokenJpaRepository;
import com.example.evstation.notification.infrastructure.push.FCMService;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final CollaboratorNotificationJpaRepository notificationRepository;
    private final NotificationPreferenceJpaRepository preferenceRepository;
    private final PushTokenJpaRepository pushTokenRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final EmailService emailService;
    private final FCMService fcmService;
    private final ObjectMapper objectMapper;
    private final ApplicationEventPublisher eventPublisher;

    // --- Send notification (publishes event for transactional safety) ---

    @Transactional
    public void send(CreateNotificationDTO dto) {
        UUID recipientId = dto.getRecipientId();
        String dataJson = serializeData(dto.getData());

        // Save in-app notification
        CollaboratorNotificationEntity entity = CollaboratorNotificationEntity.builder()
                .recipientId(recipientId)
                .type(dto.getType())
                .category(dto.getCategory())
                .title(dto.getTitle())
                .body(dto.getBody())
                .dataJson(dataJson)
                .referenceId(dto.getReferenceId())
                .referenceType(dto.getReferenceType())
                .isRead(false)
                .build();
        notificationRepository.save(entity);

        // Publish event — listener sends push + email AFTER transaction commits.
        // This prevents sending notifications if the parent transaction rolls back.
        NotificationEvent event = NotificationEvent.builder()
                .recipientId(recipientId)
                .type(dto.getType())
                .category(dto.getCategory())
                .title(dto.getTitle())
                .body(dto.getBody())
                .data(dto.getData())
                .referenceId(dto.getReferenceId())
                .referenceType(dto.getReferenceType())
                .build();
        eventPublisher.publishEvent(event);
    }

    // --- Send notification to multiple users ---

    @Transactional
    public void sendToUsers(List<UUID> recipientIds, NotificationType type, NotificationCategory category,
                            String title, String body, Map<String, Object> data,
                            UUID referenceId, String referenceType) {
        for (UUID recipientId : recipientIds) {
            send(CreateNotificationDTO.builder()
                    .recipientId(recipientId)
                    .type(type)
                    .category(category)
                    .title(title)
                    .body(body)
                    .data(data)
                    .referenceId(referenceId)
                    .referenceType(referenceType)
                    .build());
        }
    }

    // --- Send push notification ---

    @Async
    public void sendPushNotification(UUID recipientId, NotificationType type,
                                     String title, String body, Map<String, Object> data) {
        try {
            if (!isChannelEnabled(recipientId, NotificationCategory.valueOf(type.name().contains("TASK") ? "TASK" :
                    type.name().contains("CONTRACT") ? "CONTRACT" :
                    type.name().contains("STATION") ? "STATION" : "ALL"), "PUSH")) {
                log.debug("Push notifications disabled for user {}", recipientId);
                return;
            }

            PushPayload payload = PushPayload.of(type, title, body, data);
            fcmService.sendToUser(recipientId.toString(), payload);
        } catch (Exception e) {
            log.error("Failed to send push notification to {}: {}", recipientId, e.getMessage());
        }
    }

    // --- Send email notification ---

    @Async
    public void sendEmailNotification(UUID recipientId, String subject, String body) {
        try {
            NotificationCategory category = guessCategoryFromSubject(subject);
            if (!isChannelEnabled(recipientId, category, "EMAIL")) {
                log.debug("Email notifications disabled for user {} category {}", recipientId, category);
                return;
            }

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
    public NotificationPageDTO getNotifications(UUID recipientId, String category, Boolean isRead,
                                               int page, int size) {
        Page<CollaboratorNotificationEntity> result;

        NotificationCategory cat = null;
        if (category != null && !category.isBlank()) {
            cat = NotificationCategory.valueOf(category.toUpperCase());
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

        List<NotificationDTO> dtos = result.getContent().stream()
                .map(this::toDTO)
                .toList();

        return NotificationPageDTO.builder()
                .notifications(dtos)
                .totalElements(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .page(page)
                .size(size)
                .unreadCount(unreadCount)
                .build();
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

    // --- Push token management ---

    @Transactional
    public void registerPushToken(UUID userId, String token, String deviceType) {
        // Deactivate existing token if re-registering
        if (pushTokenRepository.existsByTokenAndUserId(token, userId)) {
            pushTokenRepository.touchToken(token, java.time.Instant.now());
            return;
        }

        PushTokenEntity entity = PushTokenEntity.builder()
                .userId(userId)
                .token(token)
                .deviceType(deviceType)
                .isActive(true)
                .lastUsedAt(java.time.Instant.now())
                .build();
        pushTokenRepository.save(entity);
        log.info("Push token registered for user {} device={}", userId, deviceType);
    }

    @Transactional
    public void unregisterPushToken(UUID userId, String token) {
        pushTokenRepository.findByToken(token)
                .ifPresent(entity -> {
                    entity.setIsActive(false);
                    pushTokenRepository.save(entity);
                    log.info("Push token deactivated for user {}", userId);
                });
    }

    // --- Preferences ---

    @Transactional
    public void savePreferences(UUID userId, List<PreferenceItemDTO> preferences) {
        for (PreferenceItemDTO item : preferences) {
            NotificationPreferenceEntity entity = preferenceRepository
                    .findByUserIdAndCategory(userId, item.getCategory())
                    .orElse(NotificationPreferenceEntity.builder()
                            .userId(userId)
                            .category(item.getCategory())
                            .build());

            entity.setPushEnabled(item.getPushEnabled());
            entity.setEmailEnabled(item.getEmailEnabled());
            entity.setInAppEnabled(item.getInAppEnabled());
            entity.setUpdatedAt(java.time.Instant.now());
            preferenceRepository.save(entity);
        }
    }

    @Transactional(readOnly = true)
    public NotificationPreferenceDTO getPreferences(UUID userId) {
        List<PreferenceItemDTO> items = preferenceRepository.findByUserId(userId).stream()
                .map(e -> PreferenceItemDTO.builder()
                        .category(e.getCategory())
                        .pushEnabled(e.getPushEnabled())
                        .emailEnabled(e.getEmailEnabled())
                        .inAppEnabled(e.getInAppEnabled())
                        .build())
                .toList();
        return NotificationPreferenceDTO.builder().preferences(items).build();
    }

    // --- Helpers ---

    private NotificationDTO toDTO(CollaboratorNotificationEntity entity) {
        return NotificationDTO.builder()
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

    private boolean isChannelEnabled(UUID userId, NotificationCategory category, String channel) {
        return preferenceRepository.findByUserIdAndCategory(userId, category)
                .map(pref -> {
                    if ("PUSH".equals(channel)) return pref.getPushEnabled();
                    if ("EMAIL".equals(channel)) return pref.getEmailEnabled();
                    return pref.getInAppEnabled();
                })
                .orElse(true); // Default enabled
    }

    private NotificationCategory guessCategoryFromSubject(String subject) {
        String lower = subject.toLowerCase();
        if (lower.contains("task") || lower.contains("verification") || lower.contains("verify")) {
            return NotificationCategory.TASK;
        }
        if (lower.contains("contract") || lower.contains("hợp đồng")) {
            return NotificationCategory.CONTRACT;
        }
        if (lower.contains("station") || lower.contains("trạm")) {
            return NotificationCategory.STATION;
        }
        return NotificationCategory.ALL;
    }

    /**
     * Handles NotificationEvent AFTER the parent transaction commits.
     * This ensures push + email notifications are only sent when the notification
     * record is already persisted in the database.
     */
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onNotificationEvent(NotificationEvent event) {
        log.info("[NotificationEvent] Dispatching push + email after commit for recipient={}",
                event.getRecipientId());

        // Send email asynchronously
        sendEmailNotification(event.getRecipientId(), event.getTitle(), event.getBody());

        // Send push notification
        sendPushNotification(event.getRecipientId(), event.getType(),
                event.getTitle(), event.getBody(), event.getData());
    }
}
