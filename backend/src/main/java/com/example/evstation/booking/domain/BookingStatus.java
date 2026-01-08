package com.example.evstation.booking.domain;

/**
 * Booking status enum
 * - HOLD: Booking created, waiting for payment (10 minutes)
 * - CONFIRMED: Payment completed, booking confirmed
 * - CANCELLED: User cancelled the booking
 * - EXPIRED: HOLD expired without payment
 */
public enum BookingStatus {
    HOLD,
    CONFIRMED,
    CANCELLED,
    EXPIRED
}

