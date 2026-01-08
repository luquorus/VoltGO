package com.example.evstation.booking.domain;

import java.time.Instant;
import java.util.UUID;

/**
 * Domain entity for Booking
 * Represents a booking made by an EV user for a charging slot at a station
 */
public class Booking {
    
    private final UUID id;
    private final UUID userId;
    private final UUID stationId;
    private final Instant startTime;
    private final Instant endTime;
    private final BookingStatus status;
    private final Instant holdExpiresAt;
    private final Instant createdAt;
    
    private Booking(Builder builder) {
        this.id = builder.id;
        this.userId = builder.userId;
        this.stationId = builder.stationId;
        this.startTime = builder.startTime;
        this.endTime = builder.endTime;
        this.status = builder.status;
        this.holdExpiresAt = builder.holdExpiresAt;
        this.createdAt = builder.createdAt;
    }
    
    public static Builder builder() {
        return new Builder();
    }
    
    public UUID getId() {
        return id;
    }
    
    public UUID getUserId() {
        return userId;
    }
    
    public UUID getStationId() {
        return stationId;
    }
    
    public Instant getStartTime() {
        return startTime;
    }
    
    public Instant getEndTime() {
        return endTime;
    }
    
    public BookingStatus getStatus() {
        return status;
    }
    
    public Instant getHoldExpiresAt() {
        return holdExpiresAt;
    }
    
    public Instant getCreatedAt() {
        return createdAt;
    }
    
    /**
     * Check if booking can be cancelled
     */
    public boolean canBeCancelled() {
        return status == BookingStatus.HOLD || status == BookingStatus.CONFIRMED;
    }
    
    /**
     * Check if booking is expired (HOLD status and hold_expires_at < now)
     */
    public boolean isExpired(Instant now) {
        return status == BookingStatus.HOLD && holdExpiresAt.isBefore(now);
    }
    
    public static class Builder {
        private UUID id;
        private UUID userId;
        private UUID stationId;
        private Instant startTime;
        private Instant endTime;
        private BookingStatus status;
        private Instant holdExpiresAt;
        private Instant createdAt;
        
        public Builder id(UUID id) {
            this.id = id;
            return this;
        }
        
        public Builder userId(UUID userId) {
            this.userId = userId;
            return this;
        }
        
        public Builder stationId(UUID stationId) {
            this.stationId = stationId;
            return this;
        }
        
        public Builder startTime(Instant startTime) {
            this.startTime = startTime;
            return this;
        }
        
        public Builder endTime(Instant endTime) {
            this.endTime = endTime;
            return this;
        }
        
        public Builder status(BookingStatus status) {
            this.status = status;
            return this;
        }
        
        public Builder holdExpiresAt(Instant holdExpiresAt) {
            this.holdExpiresAt = holdExpiresAt;
            return this;
        }
        
        public Builder createdAt(Instant createdAt) {
            this.createdAt = createdAt;
            return this;
        }
        
        public Booking build() {
            if (userId == null) {
                throw new IllegalArgumentException("userId is required");
            }
            if (stationId == null) {
                throw new IllegalArgumentException("stationId is required");
            }
            if (startTime == null) {
                throw new IllegalArgumentException("startTime is required");
            }
            if (endTime == null) {
                throw new IllegalArgumentException("endTime is required");
            }
            if (endTime.isBefore(startTime) || endTime.equals(startTime)) {
                throw new IllegalArgumentException("endTime must be after startTime");
            }
            if (status == null) {
                throw new IllegalArgumentException("status is required");
            }
            if (status == BookingStatus.HOLD && holdExpiresAt == null) {
                throw new IllegalArgumentException("holdExpiresAt is required when status is HOLD");
            }
            if (createdAt == null) {
                throw new IllegalArgumentException("createdAt is required");
            }
            
            return new Booking(this);
        }
    }
}

