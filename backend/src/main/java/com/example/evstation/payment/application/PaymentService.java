package com.example.evstation.payment.application;

import com.example.evstation.booking.domain.BookingStatus;
import com.example.evstation.booking.infrastructure.jpa.BookingEntity;
import com.example.evstation.booking.infrastructure.jpa.BookingJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.payment.domain.PaymentIntentStatus;
import com.example.evstation.payment.infrastructure.jpa.PaymentIntentEntity;
import com.example.evstation.payment.infrastructure.jpa.PaymentIntentJpaRepository;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {
    
    private final PaymentIntentJpaRepository paymentIntentRepository;
    private final BookingJpaRepository bookingRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final Clock clock;
    
    // Fallback amount if price snapshot is missing or invalid
    private static final int MOCK_AMOUNT_VND = 50000; // 50,000 VND
    
    /**
     * Create payment intent for a booking
     * - Allowed when booking status is HOLD and not expired
     * - Creates payment_intent with status CREATED
     * - Amount is mock fixed (can be computed based on duration later)
     * - Writes audit log PAYMENT_INTENT_CREATED
     */
    @Transactional
    public PaymentIntentResponseDTO createPaymentIntent(UUID bookingId, UUID userId) {
        log.info("Creating payment intent: bookingId={}, userId={}", bookingId, userId);
        
        // Find booking and verify ownership
        BookingEntity booking = bookingRepository.findByIdAndUserId(bookingId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Booking not found"));
        
        // Check if booking is HOLD and not expired
        if (booking.getStatus() != BookingStatus.HOLD) {
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Payment intent can only be created for HOLD bookings. Current status: " + 
                    booking.getStatus());
        }
        
        // Check if booking is expired
        Instant now = clock.instant();
        if (booking.getHoldExpiresAt().isBefore(now)) {
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Cannot create payment intent for expired booking");
        }
        
        // Check if payment intent already exists
        if (paymentIntentRepository.existsByBookingId(bookingId)) {
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Payment intent already exists for this booking");
        }
        
        // Get amount from booking price snapshot
        int amount = getAmountFromPriceSnapshot(booking.getPriceSnapshot());
        
        // Create payment intent
        Instant createdAt = now;
        PaymentIntentEntity entity = PaymentIntentEntity.builder()
                .bookingId(bookingId)
                .amount(amount)
                .currency("VND")
                .status(PaymentIntentStatus.CREATED)
                .createdAt(createdAt)
                .updatedAt(createdAt)
                .build();
        
        entity = paymentIntentRepository.save(entity);
        log.info("Payment intent created: id={}, bookingId={}, amount={}", 
                entity.getId(), bookingId, amount);
        
        // Write audit log
        writeAuditLog(userId, "EV_USER", "PAYMENT_INTENT_CREATED", 
                "PAYMENT_INTENT", entity.getId(), Map.of(
                        "bookingId", bookingId.toString(),
                        "amount", String.valueOf(amount),
                        "currency", "VND"
                ));
        
        return toDTO(entity);
    }
    
    /**
     * Simulate payment success
     * - Sets intent status to SUCCEEDED
     * - Transitions booking HOLD -> CONFIRMED (with guards)
     * - Writes audit log PAYMENT_SUCCEEDED
     * - Idempotent: calling twice should not break
     */
    @Transactional
    public PaymentIntentResponseDTO simulateSuccess(UUID intentId) {
        log.info("Simulating payment success: intentId={}", intentId);
        
        PaymentIntentEntity intent = paymentIntentRepository.findById(intentId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Payment intent not found"));
        
        // Idempotency: if already succeeded, return as-is
        if (intent.getStatus() == PaymentIntentStatus.SUCCEEDED) {
            log.info("Payment intent already succeeded: intentId={}", intentId);
            return toDTO(intent);
        }
        
        // Can only process CREATED intents
        if (intent.getStatus() != PaymentIntentStatus.CREATED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Can only simulate success for CREATED payment intents. Current status: " + 
                    intent.getStatus());
        }
        
        // Find booking
        BookingEntity booking = bookingRepository.findById(intent.getBookingId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Booking not found"));
        
        // Guards: Do not confirm if booking already CANCELLED/EXPIRED/CONFIRMED
        if (booking.getStatus() != BookingStatus.HOLD) {
            log.warn("Cannot confirm booking: bookingId={}, status={}. Setting intent to FAILED", 
                    booking.getId(), booking.getStatus());
            
            // Set intent to FAILED since booking cannot be confirmed
            intent.setStatus(PaymentIntentStatus.FAILED);
            intent.setUpdatedAt(clock.instant());
            intent = paymentIntentRepository.save(intent);
            
            writeAuditLog(null, "SYSTEM", "PAYMENT_FAILED", 
                    "PAYMENT_INTENT", intent.getId(), Map.of(
                            "reason", "Booking status is not HOLD: " + booking.getStatus(),
                            "bookingId", booking.getId().toString()
                    ));
            
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Cannot confirm booking. Booking status: " + booking.getStatus());
        }
        
        // Check if booking is expired
        Instant now = clock.instant();
        if (booking.getHoldExpiresAt().isBefore(now)) {
            log.warn("Cannot confirm expired booking: bookingId={}", booking.getId());
            
            intent.setStatus(PaymentIntentStatus.FAILED);
            intent.setUpdatedAt(now);
            intent = paymentIntentRepository.save(intent);
            
            writeAuditLog(null, "SYSTEM", "PAYMENT_FAILED", 
                    "PAYMENT_INTENT", intent.getId(), Map.of(
                            "reason", "Booking expired",
                            "bookingId", booking.getId().toString()
                    ));
            
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Cannot confirm expired booking");
        }
        
        // Update payment intent to SUCCEEDED
        intent.setStatus(PaymentIntentStatus.SUCCEEDED);
        intent.setUpdatedAt(now);
        intent = paymentIntentRepository.save(intent);
        
        // Transition booking HOLD -> CONFIRMED
        booking.setStatus(BookingStatus.CONFIRMED);
        booking = bookingRepository.save(booking);
        
        log.info("Payment succeeded and booking confirmed: intentId={}, bookingId={}", 
                intentId, booking.getId());
        
        // Write audit log
        writeAuditLog(booking.getUserId(), "EV_USER", "PAYMENT_SUCCEEDED", 
                "PAYMENT_INTENT", intent.getId(), Map.of(
                        "bookingId", booking.getId().toString(),
                        "amount", String.valueOf(intent.getAmount())
                ));
        
        return toDTO(intent);
    }
    
    /**
     * Simulate payment failure
     * - Sets intent status to FAILED
     * - Booking remains HOLD until expire
     * - Writes audit log PAYMENT_FAILED
     */
    @Transactional
    public PaymentIntentResponseDTO simulateFail(UUID intentId) {
        log.info("Simulating payment failure: intentId={}", intentId);
        
        PaymentIntentEntity intent = paymentIntentRepository.findById(intentId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Payment intent not found"));
        
        // Can only fail CREATED intents
        if (intent.getStatus() != PaymentIntentStatus.CREATED) {
            throw new BusinessException(ErrorCode.INVALID_STATE, 
                    "Can only simulate failure for CREATED payment intents. Current status: " + 
                    intent.getStatus());
        }
        
        // Update payment intent to FAILED
        Instant now = clock.instant();
        intent.setStatus(PaymentIntentStatus.FAILED);
        intent.setUpdatedAt(now);
        intent = paymentIntentRepository.save(intent);
        
        log.info("Payment failed: intentId={}, bookingId={}", intentId, intent.getBookingId());
        
        // Write audit log
        BookingEntity booking = bookingRepository.findById(intent.getBookingId())
                .orElse(null);
        UUID userId = booking != null ? booking.getUserId() : null;
        
        writeAuditLog(userId, "EV_USER", "PAYMENT_FAILED", 
                "PAYMENT_INTENT", intent.getId(), Map.of(
                        "bookingId", intent.getBookingId().toString(),
                        "amount", String.valueOf(intent.getAmount())
                ));
        
        return toDTO(intent);
    }
    
    /**
     * Get payment amount from booking price snapshot
     */
    private int getAmountFromPriceSnapshot(Map<String, Object> priceSnapshot) {
        if (priceSnapshot == null || priceSnapshot.isEmpty()) {
            log.warn("Price snapshot is null or empty, using fallback amount");
            return MOCK_AMOUNT_VND;
        }
        
        Object amountObj = priceSnapshot.get("amount");
        if (amountObj == null) {
            log.warn("Amount not found in price snapshot, using fallback amount");
            return MOCK_AMOUNT_VND;
        }
        
        // Handle different numeric types (Integer, Long, Double, etc.)
        if (amountObj instanceof Number) {
            return ((Number) amountObj).intValue();
        }
        
        // Try to parse as string
        try {
            return Integer.parseInt(amountObj.toString());
        } catch (NumberFormatException e) {
            log.warn("Cannot parse amount from price snapshot: {}, using fallback amount", amountObj);
            return MOCK_AMOUNT_VND;
        }
    }
    
    private PaymentIntentResponseDTO toDTO(PaymentIntentEntity entity) {
        return PaymentIntentResponseDTO.builder()
                .id(entity.getId())
                .bookingId(entity.getBookingId())
                .amount(entity.getAmount())
                .currency(entity.getCurrency())
                .status(entity.getStatus().name())
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt())
                .build();
    }
    
    private void writeAuditLog(UUID actorId, String actorRole, String action, 
                               String entityType, UUID entityId, Map<String, Object> metadata) {
        AuditLogEntity auditLog = AuditLogEntity.builder()
                .actorId(actorId != null ? actorId : UUID.fromString("00000000-0000-0000-0000-000000000000"))
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

