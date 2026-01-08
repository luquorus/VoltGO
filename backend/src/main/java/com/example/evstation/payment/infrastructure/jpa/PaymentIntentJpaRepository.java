package com.example.evstation.payment.infrastructure.jpa;

import com.example.evstation.payment.domain.PaymentIntentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface PaymentIntentJpaRepository extends JpaRepository<PaymentIntentEntity, UUID> {
    
    /**
     * Find payment intent by booking ID
     */
    Optional<PaymentIntentEntity> findByBookingId(UUID bookingId);
    
    /**
     * Check if payment intent exists for booking
     */
    boolean existsByBookingId(UUID bookingId);
    
    /**
     * Find payment intent by ID and status
     */
    Optional<PaymentIntentEntity> findByIdAndStatus(UUID id, PaymentIntentStatus status);
}

