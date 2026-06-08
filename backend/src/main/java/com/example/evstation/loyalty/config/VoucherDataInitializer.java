package com.example.evstation.loyalty.config;

import com.example.evstation.loyalty.domain.*;
import com.example.evstation.loyalty.infrastructure.jpa.VoucherDefinitionJpaRepository;
import com.example.evstation.loyalty.infrastructure.jpa.VoucherDefinitionEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class VoucherDataInitializer implements CommandLineRunner {

    private final VoucherDefinitionJpaRepository definitionRepository;

    @Override
    public void run(String... args) {
        if (definitionRepository.count() > 0) {
            log.info("Voucher definitions already seeded, skipping");
            return;
        }

        List<VoucherDefinitionEntity> vouchers = List.of(
            VoucherDefinitionEntity.builder()
                    .code("FIVE_PCT_OFF")
                    .name("Giảm 5% tổng bill")
                    .description("Giảm 5% giá trị đơn hàng sạc pin hoặc đổi pin. Tối đa 10,000 VND.")
                    .voucherType(VoucherType.PERCENT_DISCOUNT)
                    .pointCost(200)
                    .discountPercent(5)
                    .maxValueVnd(10000)
                    .status(VoucherStatus.ACTIVE)
                    .validityDays(30)
                    .build(),
            VoucherDefinitionEntity.builder()
                    .code("TEN_PCT_OFF")
                    .name("Giảm 10% tổng bill")
                    .description("Giảm 10% giá trị đơn hàng sạc pin hoặc đổi pin. Tối đa 20,000 VND.")
                    .voucherType(VoucherType.PERCENT_DISCOUNT)
                    .pointCost(300)
                    .discountPercent(10)
                    .maxValueVnd(20000)
                    .status(VoucherStatus.ACTIVE)
                    .validityDays(30)
                    .build(),
            VoucherDefinitionEntity.builder()
                    .code("FREE_CHARGING")
                    .name("Free 1 lần charging")
                    .description("Miễn phí hoàn toàn 1 lần sạc pin. Áp dụng cho tất cả các trạm sạc.")
                    .voucherType(VoucherType.FREE_SERVICE)
                    .pointCost(500)
                    .serviceType("CHARGING")
                    .status(VoucherStatus.ACTIVE)
                    .validityDays(30)
                    .build(),
            VoucherDefinitionEntity.builder()
                    .code("FREE_SWAP")
                    .name("Free 1 lần swapping battery")
                    .description("Miễn phí hoàn toàn 1 lần đổi pin. Áp dụng cho tất cả các trạm đổi pin.")
                    .voucherType(VoucherType.FREE_SERVICE)
                    .pointCost(500)
                    .serviceType("BATTERY_SWAP")
                    .status(VoucherStatus.ACTIVE)
                    .validityDays(30)
                    .build()
        );

        Instant now = Instant.now();
        for (VoucherDefinitionEntity v : vouchers) {
            v.setId(UUID.randomUUID());
            v.setCreatedAt(now);
            v.setUpdatedAt(now);
        }

        definitionRepository.saveAll(vouchers);
        log.info("Seeded {} voucher definitions", vouchers.size());
    }
}
