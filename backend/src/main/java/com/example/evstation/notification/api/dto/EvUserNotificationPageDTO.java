package com.example.evstation.notification.api.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EvUserNotificationPageDTO {
    private List<EvUserNotificationDTO> notifications;
    private long totalElements;
    private int totalPages;
    private int page;
    private int size;
    private long unreadCount;
}
