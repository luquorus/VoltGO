package com.example.evstation.loyalty.config;

import com.example.evstation.loyalty.application.VoucherService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class VoucherExpirationScheduler {
    private final VoucherService voucherService;

    @Scheduled(cron = "0 0 0 * * *")
    public void expireVouchers() {
        log.info("Running voucher expiration job");
        int count = voucherService.expireRedemptions();
        log.info("Voucher expiration job done, expired {} vouchers", count);
    }
}
