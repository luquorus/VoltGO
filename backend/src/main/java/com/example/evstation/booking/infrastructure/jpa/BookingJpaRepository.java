package com.example.evstation.booking.infrastructure.jpa;

import com.example.evstation.booking.domain.BookingStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingJpaRepository extends JpaRepository<BookingEntity, UUID> {
    
    /**
     * Find all bookings for a user, ordered by created_at DESC
     */
    Page<BookingEntity> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
    
    /**
     * Find booking by ID and user ID (for authorization check)
     */
    Optional<BookingEntity> findByIdAndUserId(UUID id, UUID userId);
    
    /**
     * Find all HOLD bookings that have expired (hold_expires_at < now)
     * Used by scheduler to expire bookings
     */
    @Query("""
        SELECT b FROM BookingEntity b 
        WHERE b.status = :status 
        AND b.holdExpiresAt < :now
        ORDER BY b.holdExpiresAt ASC
        """)
    List<BookingEntity> findExpiredHoldBookings(
            @Param("status") BookingStatus status,
            @Param("now") Instant now);
    
    /**
     * Count active bookings (HOLD or CONFIRMED) for a station in a time range
     * Used for future slot availability checks
     */
    @Query("""
        SELECT COUNT(b) FROM BookingEntity b 
        WHERE b.stationId = :stationId 
        AND b.status IN ('HOLD', 'CONFIRMED')
        AND (
            (b.startTime <= :startTime AND b.endTime > :startTime)
            OR (b.startTime < :endTime AND b.endTime >= :endTime)
            OR (b.startTime >= :startTime AND b.endTime <= :endTime)
        )
        """)
    long countOverlappingBookings(
            @Param("stationId") UUID stationId,
            @Param("startTime") Instant startTime,
            @Param("endTime") Instant endTime);
}

