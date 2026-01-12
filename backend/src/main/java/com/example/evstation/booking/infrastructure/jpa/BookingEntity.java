package com.example.evstation.booking.infrastructure.jpa;

import com.example.evstation.booking.domain.BookingStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Entity
@Table(name = "booking", indexes = {
    @Index(name = "idx_booking_user_id", columnList = "user_id"),
    @Index(name = "idx_booking_station_id", columnList = "station_id"),
    @Index(name = "idx_booking_status", columnList = "status"),
    @Index(name = "idx_booking_created_at", columnList = "created_at"),
    @Index(name = "idx_booking_start_time", columnList = "start_time"),
    @Index(name = "idx_booking_user_status", columnList = "user_id, status")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BookingEntity {
    
    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();
    
    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;
    
    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;
    
    @Column(name = "charger_unit_id", nullable = false, columnDefinition = "UUID")
    private UUID chargerUnitId;
    
    @Column(name = "start_time", nullable = false)
    private Instant startTime;
    
    @Column(name = "end_time", nullable = false)
    private Instant endTime;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private BookingStatus status = BookingStatus.HOLD;
    
    @Column(name = "hold_expires_at", nullable = false)
    private Instant holdExpiresAt;
    
    @Column(name = "price_snapshot", nullable = false, columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    @Builder.Default
    private Map<String, Object> priceSnapshot = Map.of();
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}

