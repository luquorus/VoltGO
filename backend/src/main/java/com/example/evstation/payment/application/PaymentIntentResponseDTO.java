package com.example.evstation.payment.application;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
public class PaymentIntentResponseDTO {
    
    private UUID id;
    private UUID bookingId;
    private Integer amount;
    private String currency;
    private String status; // CREATED, SUCCEEDED, FAILED
    private Instant createdAt;
    private Instant updatedAt;
}

