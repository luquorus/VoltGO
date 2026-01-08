package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.payment.application.PaymentIntentResponseDTO;
import com.example.evstation.payment.application.PaymentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@Tag(name = "Payments", description = "API for payment intents and payment simulation")
@RestController
@RequestMapping("/api/ev")
@RequiredArgsConstructor
@PreAuthorize("hasRole('EV_USER')")
public class PaymentController {
    
    private final PaymentService paymentService;
    
    @Operation(
        summary = "Create payment intent for a booking",
        description = "Create a payment intent for a HOLD booking. " +
                      "Booking must be HOLD status and not expired. " +
                      "Only one payment intent can exist per booking."
    )
    @PostMapping("/bookings/{bookingId}/payment-intent")
    public ResponseEntity<PaymentIntentResponseDTO> createPaymentIntent(
            @Parameter(description = "Booking ID", required = true)
            @PathVariable UUID bookingId,
            Authentication authentication) {
        
        UUID userId = extractUserId(authentication);
        log.info("Creating payment intent: bookingId={}, userId={}", bookingId, userId);
        
        PaymentIntentResponseDTO response = paymentService.createPaymentIntent(bookingId, userId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
    
    @Operation(
        summary = "Simulate payment success",
        description = "Simulate a successful payment. " +
                      "Sets payment intent to SUCCEEDED and transitions booking HOLD -> CONFIRMED. " +
                      "Idempotent: calling twice returns the same result."
    )
    @PostMapping("/payments/{intentId}/simulate-success")
    public ResponseEntity<PaymentIntentResponseDTO> simulateSuccess(
            @Parameter(description = "Payment Intent ID", required = true)
            @PathVariable UUID intentId) {
        
        log.info("Simulating payment success: intentId={}", intentId);
        
        PaymentIntentResponseDTO response = paymentService.simulateSuccess(intentId);
        return ResponseEntity.ok(response);
    }
    
    @Operation(
        summary = "Simulate payment failure",
        description = "Simulate a failed payment. " +
                      "Sets payment intent to FAILED. " +
                      "Booking remains HOLD until it expires."
    )
    @PostMapping("/payments/{intentId}/simulate-fail")
    public ResponseEntity<PaymentIntentResponseDTO> simulateFail(
            @Parameter(description = "Payment Intent ID", required = true)
            @PathVariable UUID intentId) {
        
        log.info("Simulating payment failure: intentId={}", intentId);
        
        PaymentIntentResponseDTO response = paymentService.simulateFail(intentId);
        return ResponseEntity.ok(response);
    }
    
    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) {
            return (UUID) principal;
        }
        return UUID.fromString(principal.toString());
    }
}

