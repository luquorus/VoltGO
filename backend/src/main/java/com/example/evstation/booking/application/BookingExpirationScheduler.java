package com.example.evstation.booking.application;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Scheduler to expire HOLD bookings
 * Runs every 1 minute to find and expire bookings where hold_expires_at < now
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class BookingExpirationScheduler {
    
    private final BookingService bookingService;
    
    /**
     * Expire HOLD bookings every 1 minute
     * Fixed delay: wait 1 minute after previous execution completes
     */
    @Scheduled(fixedDelay = 60000) // 60 seconds = 1 minute
    public void expireHoldBookings() {
        try {
            int expiredCount = bookingService.expireHoldBookings();
            if (expiredCount > 0) {
                log.info("Scheduler expired {} HOLD bookings", expiredCount);
            }
        } catch (Exception e) {
            log.error("Error expiring HOLD bookings", e);
        }
    }
}

