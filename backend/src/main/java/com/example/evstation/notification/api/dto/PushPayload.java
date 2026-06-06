package com.example.evstation.notification.api.dto;

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
public class PushPayload {
    private NotificationType type;
    private String title;
    private String body;
    private Map<String, Object> data;

    public static PushPayload of(NotificationType type, String title, String body, Map<String, Object> data) {
        return PushPayload.builder()
                .type(type)
                .title(title)
                .body(body)
                .data(data)
                .build();
    }
}
