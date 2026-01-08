package com.example.evstation.payment.domain;

/**
 * Payment Intent status enum
 * - CREATED: Payment intent created, waiting for payment
 * - SUCCEEDED: Payment successful, booking confirmed
 * - FAILED: Payment failed, booking remains HOLD
 */
public enum PaymentIntentStatus {
    CREATED,
    SUCCEEDED,
    FAILED
}

