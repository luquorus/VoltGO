package com.example.evstation.booking.application;

import com.example.evstation.booking.domain.BookingStatus;
import com.example.evstation.booking.domain.ChargerUnitStatus;
import com.example.evstation.booking.infrastructure.jpa.BookingEntity;
import com.example.evstation.booking.infrastructure.jpa.BookingJpaRepository;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitEntity;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
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
    private final ChargerUnitJpaRepository chargerUnitRepository;
    private final Clock clock;
    
    private static final Duration HOLD_DURATION = Duration.ofMinutes(10);
    private static final int MIN_BOOKING_DURATION_MINUTES = 15;
    private static final int MAX_BOOKING_DURATION_HOURS = 4;
    
    /**
     * Create a new booking with HOLD status
     * - Validates station exists and has published version
     * - Validates charger unit exists, belongs to station, and is ACTIVE
     * - Validates time range (15 min - 4 hours, startTime in future)
     * - Creates booking with status HOLD, hold_expires_at = now + 10 minutes
     * - Calculates price snapshot
     * - Writes audit log BOOKING_HOLD_CREATED
     */
    @Transactional
    public BookingResponseDTO createBooking(CreateBookingDTO request, UUID userId) {
        log.info("Creating booking: stationId={}, chargerUnitId={}, startTime={}, endTime={}, userId={}", 
                request.getStationId(), request.getChargerUnitId(), request.getStartTime(), request.getEndTime(), userId);
        
        Instant now = clock.instant();
        
        // Validate station exists and has published version
        boolean stationPublished = stationVersionRepository
                .findByStationIdAndWorkflowStatus(request.getStationId(), WorkflowStatus.PUBLISHED)
                .isPresent();
        
        if (!stationPublished) {
            throw new BusinessException(ErrorCode.NOT_FOUND, 
                    "Station not found or does not have a published version");
        }
        
        // Validate charger unit exists and belongs to station
        ChargerUnitEntity chargerUnit = chargerUnitRepository
                .findByIdAndStationId(request.getChargerUnitId(), request.getStationId())
                .orElseThrow(() -> new BusinessException(ErrorCode.CHARGER_UNIT_NOT_FOUND,
                        "Charger unit not found or does not belong to station"));
        
        // Validate charger unit is ACTIVE
        if (chargerUnit.getStatus() != ChargerUnitStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.CHARGER_UNIT_INACTIVE,
                    "Charger unit is not active. Status: " + chargerUnit.getStatus());
        }
        
        // Validate time range - must be at least 30 minutes in the future
        Instant minStartTime = now.plus(Duration.ofMinutes(30));
        if (request.getStartTime().isBefore(minStartTime)) {
            throw new BusinessException(ErrorCode.INVALID_TIME_RANGE, 
                    "startTime must be at least 30 minutes in the future");
        }
        if (request.getEndTime().isBefore(request.getStartTime()) || 
            request.getEndTime().equals(request.getStartTime())) {
            throw new BusinessException(ErrorCode.INVALID_TIME_RANGE, 
                    "endTime must be after startTime");
        }
        
        // Validate duration (15 minutes to 4 hours)
        Duration duration = Duration.between(request.getStartTime(), request.getEndTime());
        long durationMinutes = duration.toMinutes();
        if (durationMinutes < MIN_BOOKING_DURATION_MINUTES) {
            throw new BusinessException(ErrorCode.INVALID_TIME_RANGE,
                    "Booking duration must be at least " + MIN_BOOKING_DURATION_MINUTES + " minutes");
        }
        if (durationMinutes > MAX_BOOKING_DURATION_HOURS * 60) {
            throw new BusinessException(ErrorCode.INVALID_TIME_RANGE,
                    "Booking duration must be at most " + MAX_BOOKING_DURATION_HOURS + " hours");
        }
        
        // Calculate price snapshot
        Map<String, Object> priceSnapshot = calculatePriceSnapshot(chargerUnit, durationMinutes);
        
        // Create booking entity
        Instant holdExpiresAt = now.plus(HOLD_DURATION);
        BookingEntity entity = BookingEntity.builder()
                .userId(userId)
                .stationId(request.getStationId())
                .chargerUnitId(request.getChargerUnitId())
                .startTime(request.getStartTime())
                .endTime(request.getEndTime())
                .status(BookingStatus.HOLD)
                .holdExpiresAt(holdExpiresAt)
                .priceSnapshot(priceSnapshot)
                .createdAt(now)
                .build();
        
        try {
            entity = bookingRepository.save(entity);
            log.info("Booking created: id={}, status=HOLD, expiresAt={}", 
                    entity.getId(), entity.getHoldExpiresAt());
        } catch (DataIntegrityViolationException e) {
            // Catch exclusion constraint violation (double-booking)
            // Check exception message at all levels
            String exceptionMessage = e.getMessage() != null ? e.getMessage() : "";
            
            // Check root cause message
            Throwable cause = e.getCause();
            String causeMessage = "";
            while (cause != null) {
                if (cause.getMessage() != null) {
                    causeMessage += " " + cause.getMessage();
                }
                cause = cause.getCause();
            }
            
            String fullMessage = exceptionMessage + causeMessage;
            log.debug("DataIntegrityViolationException: message={}", fullMessage);
            
            if (fullMessage.contains("ck_booking_no_overlap_active")) {
                log.warn("Double-booking detected: slot already booked or held");
                throw new BusinessException(ErrorCode.SLOT_UNAVAILABLE,
                        "Slot is already booked or held. Please choose a different time slot.");
            }
            throw e; // Re-throw if it's a different constraint violation
        }
        
        // Write audit log
        writeAuditLog(userId, "EV_USER", "BOOKING_HOLD_CREATED", 
                "BOOKING", entity.getId(), Map.of(
                        "stationId", entity.getStationId().toString(),
                        "chargerUnitId", entity.getChargerUnitId().toString(),
                        "startTime", entity.getStartTime().toString(),
                        "endTime", entity.getEndTime().toString(),
                        "holdExpiresAt", entity.getHoldExpiresAt().toString()
                ));
        
        return toDTO(entity);
    }
    
    private Map<String, Object> calculatePriceSnapshot(ChargerUnitEntity chargerUnit, long durationMinutes) {
        Map<String, Object> snapshot = new HashMap<>();
        snapshot.put("unitLabel", chargerUnit.getLabel());
        snapshot.put("powerType", chargerUnit.getPowerType().name());
        snapshot.put("powerKw", chargerUnit.getPowerKw() != null ? chargerUnit.getPowerKw().doubleValue() : null);
        snapshot.put("pricePerSlot", chargerUnit.getPricePerSlot());
        snapshot.put("durationMinutes", (int) durationMinutes);
        
        // Calculate amount: price per slot * number of slots (slots are 30 minutes each)
        // Round up to nearest slot
        long slotCount = (durationMinutes + 29) / 30; // Round up to nearest 30 minutes
        int amount = chargerUnit.getPricePerSlot() * (int) slotCount;
        snapshot.put("slotCount", (int) slotCount);
        snapshot.put("amount", amount);
        
        return snapshot;
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
                .chargerUnitId(entity.getChargerUnitId())
                .startTime(entity.getStartTime())
                .endTime(entity.getEndTime())
                .status(entity.getStatus().name())
                .holdExpiresAt(entity.getHoldExpiresAt())
                .createdAt(entity.getCreatedAt())
                .priceSnapshot(entity.getPriceSnapshot())
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

