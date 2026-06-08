package com.example.evstation.notification.infrastructure.jpa;

import com.example.evstation.notification.domain.EvUserNotificationCategory;
import com.example.evstation.notification.domain.EvUserNotificationType;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ev_user_notification", indexes = {
    @Index(name = "idx_ev_notification_recipient", columnList = "recipient_id"),
    @Index(name = "idx_ev_notification_category", columnList = "category"),
    @Index(name = "idx_ev_notification_read", columnList = "is_read"),
    @Index(name = "idx_ev_notification_created_at", columnList = "created_at")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EvUserNotificationEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    /** The EV user account ID who receives this notification */
    @Column(name = "recipient_id", nullable = false, columnDefinition = "UUID")
    private UUID recipientId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EvUserNotificationType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EvUserNotificationCategory category;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    /** JSON payload with additional data (bookingId, stationId, etc.) */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private String dataJson;

    @Column(name = "is_read", nullable = false)
    @Builder.Default
    private Boolean isRead = false;

    /** Reference entity for navigation (booking_id, station_id, change_request_id, etc.) */
    @Column(name = "reference_id", columnDefinition = "UUID")
    private UUID referenceId;

    /** Reference entity type (BOOKING, STATION, CHANGE_REQUEST, BATTERY_SWAP_RESERVATION, etc.) */
    @Column(name = "reference_type")
    private String referenceType;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) id = UUID.randomUUID();
        if (createdAt == null) createdAt = Instant.now();
        // Auto-derive category from type if not explicitly set
        if (category == null && type != null) {
            category = type.getCategory();
        }
    }
}
