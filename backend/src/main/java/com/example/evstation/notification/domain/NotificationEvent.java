package com.example.evstation.notification.domain;

import lombok.Builder;
import lombok.Getter;

import java.util.Map;
import java.util.UUID;

/**
 * Domain event published after a notification should be sent.
 * Used with @TransactionalEventListener to ensure notification is only dispatched
 * after the parent transaction commits successfully.
 */
@Getter
public class NotificationEvent {

    private final UUID recipientId;
    private final NotificationType type;
    private final NotificationCategory category;
    private final String title;
    private final String body;
    private final Map<String, Object> data;
    private final UUID referenceId;
    private final String referenceType;

    @Builder
    public NotificationEvent(UUID recipientId, NotificationType type, NotificationCategory category,
                            String title, String body, Map<String, Object> data,
                            UUID referenceId, String referenceType) {
        this.recipientId = recipientId;
        this.type = type;
        this.category = category;
        this.title = title;
        this.body = body;
        this.data = data;
        this.referenceId = referenceId;
        this.referenceType = referenceType;
    }
}
