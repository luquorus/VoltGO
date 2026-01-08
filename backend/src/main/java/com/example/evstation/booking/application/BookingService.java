package com.example.evstation.booking.application;

import com.example.evstation.booking.domain.BookingStatus;
import com.example.evstation.booking.infrastructure.jpa.BookingEntity;
import com.example.evstation.booking.infrastructure.jpa.BookingJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BookingService {
    
    private final BookingJpaRepository bookingRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final Clock clock;
    
    private static final Duration HOLD_DURATION = Duration.ofMinutes(10);
    
    /**
     * Create a new booking with HOLD status
     * - Validates station exists and has published version
     * - Creates booking with status HOLD, hold_expires_at = now + 10 minutes
     * - Writes audit log BOOKING_HOLD_CREATED
     */
    @Transactional
    public BookingResponseDTO createBooking(CreateBookingDTO request, UUID userId) {
        log.info("Creating booking: stationId={}, startTime={}, endTime={}, userId={}", 
                request.getStationId(), request.getStartTime(), request.getEndTime(), userId);
        
        // Validate station exists and has published version
        boolean stationPublished = stationVersionRepository
                .findByStationIdAndWorkflowStatus(request.getStationId(), WorkflowStatus.PUBLISHED)
                .isPresent();
        
        if (!stationPublished) {
            throw new BusinessException(ErrorCode.NOT_FOUND, 
                    "Station not found or does not have a published version");
        }
        
        // Validate time range
        Instant now = clock.instant();
        if (request.getStartTime().isBefore(now)) {
            throw new BusinessException(ErrorCode.INVALID_INPUT, 
                    "startTime must be in the future");
        }
        if (request.getEndTime().isBefore(request.getStartTime()) || 
            request.getEndTime().equals(request.getStartTime())) {
            throw new BusinessException(ErrorCode.INVALID_INPUT, 
                    "endTime must be after startTime");
        }
        
        // Create booking entity
        Instant holdExpiresAt = now.plus(HOLD_DURATION);
        BookingEntity entity = BookingEntity.builder()
                .userId(userId)
                .stationId(request.getStationId())
                .startTime(request.getStartTime())
                .endTime(request.getEndTime())
                .status(BookingStatus.HOLD)
                .holdExpiresAt(holdExpiresAt)
                .createdAt(now)
                .build();
        
        entity = bookingRepository.save(entity);
        log.info("Booking created: id={}, status=HOLD, expiresAt={}", 
                entity.getId(), entity.getHoldExpiresAt());
        
        // Write audit log
        writeAuditLog(userId, "EV_USER", "BOOKING_HOLD_CREATED", 
                "BOOKING", entity.getId(), Map.of(
                        "stationId", entity.getStationId().toString(),
                        "startTime", entity.getStartTime().toString(),
                        "endTime", entity.getEndTime().toString(),
                        "holdExpiresAt", entity.getHoldExpiresAt().toString()
                ));
        
        return toDTO(entity);
    }
    
    /**
     * Get all bookings for a user (paginated)
     */
    @Transactional(readOnly = true)
    public Page<BookingResponseDTO> getMyBookings(UUID userId, Pageable pageable) {
        log.debug("Getting bookings for user: {}", userId);
        return bookingRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable)
                .map(this::toDTO);
    }
    
    /**
     * Get booking by ID (only if belongs to user)
     */
    @Transactional(readOnly = true)
    public Optional<BookingResponseDTO> getBooking(UUID bookingId, UUID userId) {
        log.debug("Getting booking: id={}, userId={}", bookingId, userId);
        return bookingRepository.findByIdAndUserId(bookingId, userId)
                .map(this::toDTO);
    }
    
    /**
     * Cancel a booking
     * Allowed when status is HOLD or CONFIRMED
     */
    @Transactional
    public BookingResponseDTO cancelBooking(UUID bookingId, UUID userId) {
        log.info("Cancelling booking: id={}, userId={}", bookingId, userId);
        
        BookingEntity entity = bookingRepository.findByIdAndUserId(bookingId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Booking not found"));
        
        BookingStatus previousStatus = entity.getStatus();
        
        if (previousStatus != BookingStatus.HOLD && 
            previousStatus != BookingStatus.CONFIRMED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Booking can only be cancelled when status is HOLD or CONFIRMED. Current status: " + 
                    previousStatus);
        }
        
        entity.setStatus(BookingStatus.CANCELLED);
        entity = bookingRepository.save(entity);
        log.info("Booking cancelled: id={}, previousStatus={}", bookingId, previousStatus);
        
        // Write audit log
        writeAuditLog(userId, "EV_USER", "BOOKING_CANCELLED", 
                "BOOKING", entity.getId(), Map.of(
                        "previousStatus", previousStatus.toString()
                ));
        
        return toDTO(entity);
    }
    
    /**
     * Expire HOLD bookings (called by scheduler)
     * Finds all HOLD bookings where hold_expires_at < now
     */
    @Transactional
    public int expireHoldBookings() {
        Instant now = clock.instant();
        log.debug("Expiring HOLD bookings: now={}", now);
        
        var expiredBookings = bookingRepository.findExpiredHoldBookings(
                BookingStatus.HOLD, now);
        
        int count = 0;
        for (BookingEntity entity : expiredBookings) {
            entity.setStatus(BookingStatus.EXPIRED);
            bookingRepository.save(entity);
            
            // Write audit log
            writeAuditLog(entity.getUserId(), "EV_USER", "BOOKING_EXPIRED", 
                    "BOOKING", entity.getId(), Map.of(
                            "holdExpiresAt", entity.getHoldExpiresAt().toString()
                    ));
            
            count++;
            log.debug("Expired booking: id={}, userId={}", entity.getId(), entity.getUserId());
        }
        
        if (count > 0) {
            log.info("Expired {} HOLD bookings", count);
        }
        
        return count;
    }
    
    private BookingResponseDTO toDTO(BookingEntity entity) {
        return BookingResponseDTO.builder()
                .id(entity.getId())
                .userId(entity.getUserId())
                .stationId(entity.getStationId())
                .startTime(entity.getStartTime())
                .endTime(entity.getEndTime())
                .status(entity.getStatus().name())
                .holdExpiresAt(entity.getHoldExpiresAt())
                .createdAt(entity.getCreatedAt())
                .build();
    }
    
    private void writeAuditLog(UUID actorId, String actorRole, String action, 
                               String entityType, UUID entityId, Map<String, Object> metadata) {
        AuditLogEntity auditLog = AuditLogEntity.builder()
                .actorId(actorId)
                .actorRole(actorRole)
                .action(action)
                .entityType(entityType)
                .entityId(entityId)
                .metadata(metadata)
                .createdAt(clock.instant())
                .build();
        auditLogRepository.save(auditLog);
        log.debug("Audit log written: action={}, entityType={}, entityId={}", 
                action, entityType, entityId);
    }
}

