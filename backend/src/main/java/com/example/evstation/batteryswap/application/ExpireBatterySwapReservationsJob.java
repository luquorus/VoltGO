package com.example.evstation.batteryswap.application;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ExpireBatterySwapReservationsJob {

    private final BatterySwapService batterySwapService;
    private final SwapCodeService swapCodeService;

    @Value("${voltgo.battery-swap.expire-job-interval-ms:60000}")
    private long expireJobIntervalMs;

    @Value("${voltgo.battery-swap.payment-expire-job-interval-ms:60000}")
    private long paymentExpireJobIntervalMs;

    @Scheduled(fixedDelayString = "${voltgo.battery-swap.expire-job-interval-ms:60000}")
    public void run() {
        try {
            batterySwapService.expireStaleReservations();
        } catch (Exception e) {
            log.error("expireStaleReservations failed", e);
        }
    }

    @Scheduled(fixedDelayString = "${voltgo.battery-swap.payment-expire-job-interval-ms:60000}")
    public void runPaymentExpiry() {
        try {
            batterySwapService.expireUnpaidReservations();
        } catch (Exception e) {
            log.error("expireUnpaidReservations failed", e);
        }
    }

    @Scheduled(fixedDelayString = "${voltgo.battery-swap.swap-deadline-interval-ms:60000}")
    public void runSwapDeadlineExpiry() {
        try {
            batterySwapService.expireSwapDeadline();
        } catch (Exception e) {
            log.error("expireSwapDeadline failed", e);
        }
    }

    @Scheduled(fixedDelayString = "${voltgo.battery-swap.swap-session-interval-ms:30000}")
    public void runSwapCodeExpiry() {
        try {
            swapCodeService.expirePendingSessions();
        } catch (Exception e) {
            log.error("expirePendingSwapSessions failed", e);
        }
    }
}
