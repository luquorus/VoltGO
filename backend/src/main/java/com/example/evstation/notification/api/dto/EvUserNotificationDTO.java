package com.example.evstation.notification.api.dto;

import com.example.evstation.notification.domain.EvUserNotificationCategory;
import com.example.evstation.notification.domain.EvUserNotificationType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EvUserNotificationDTO {
    private UUID id;
    private EvUserNotificationType type;
    private EvUserNotificationCategory category;
    private String title;
    private String body;
    private Map<String, Object> data;
    private Boolean isRead;
    private UUID referenceId;
    private String referenceType;
    private Instant createdAt;
}
