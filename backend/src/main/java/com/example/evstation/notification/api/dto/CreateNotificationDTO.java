package com.example.evstation.notification.api.dto;

import com.example.evstation.notification.domain.NotificationCategory;
import com.example.evstation.notification.domain.NotificationType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateNotificationDTO {
    private UUID recipientId;
    private NotificationType type;
    private NotificationCategory category;
    private String title;
    private String body;
    private Map<String, Object> data;
    private UUID referenceId;
    private String referenceType;
}
