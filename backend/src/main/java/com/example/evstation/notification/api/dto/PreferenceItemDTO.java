package com.example.evstation.notification.api.dto;

import com.example.evstation.notification.domain.NotificationCategory;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PreferenceItemDTO {
    private NotificationCategory category;
    private Boolean pushEnabled;
    private Boolean emailEnabled;
    private Boolean inAppEnabled;
}
