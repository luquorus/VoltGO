package com.example.evstation.notification.api.dto;

import com.example.evstation.notification.domain.NotificationCategory;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationPageDTO {
    private List<NotificationDTO> notifications;
    private long totalElements;
    private int totalPages;
    private int page;
    private int size;
    private long unreadCount;
}
