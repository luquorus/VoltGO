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
     * Find bookings for charger units in a time range (for availability check)
     * Returns bookings that overlap with the time range and are active (HOLD or CONFIRMED)
     */
    @Query("""
        SELECT b FROM BookingEntity b 
        WHERE b.chargerUnitId IN :chargerUnitIds
        AND b.status IN ('HOLD', 'CONFIRMED')
        AND b.startTime < :dayEnd
        AND b.endTime > :dayStart
        ORDER BY b.chargerUnitId, b.startTime
        """)
    List<BookingEntity> findBookingsForAvailability(
            @Param("chargerUnitIds") List<UUID> chargerUnitIds,
            @Param("dayStart") Instant dayStart,
            @Param("dayEnd") Instant dayEnd);
}

