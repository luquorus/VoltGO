package com.example.evstation.loyalty.application;

import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.loyalty.domain.PointSource;
import com.example.evstation.loyalty.domain.ReferralStatus;
import com.example.evstation.loyalty.infrastructure.jpa.ReferralEntity;
import com.example.evstation.loyalty.infrastructure.jpa.ReferralJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class ReferralService {

    private final ReferralJpaRepository referralRepository;
    private final LoyaltyPointService loyaltyPointService;

    @Transactional
    public String generateReferralCode(UUID userId) {
        String code = UUID.randomUUID().toString().substring(0, 8).toUpperCase();
        ReferralEntity referral = ReferralEntity.builder()
                .referrerId(userId)
                .referralCode(code)
                .status(ReferralStatus.PENDING)
                .build();
        referralRepository.save(referral);
        log.info("Generated referral code {} for user {}", code, userId);
        return code;
    }

    @Transactional
    public void onReferralSignup(String referralCode, UUID refereeId) {
        var allReferrals = referralRepository.findAll().stream()
                .filter(r -> r.getReferralCode().equalsIgnoreCase(referralCode))
                .toList();
        if (allReferrals.isEmpty()) return;
        ReferralEntity referral = allReferrals.get(0);
        if (referral.getRefereeId() != null) return;
        referral.setRefereeId(refereeId);
        referral.setStatus(ReferralStatus.REGISTERED);
        referralRepository.save(referral);
        log.info("Referral registered: referrer={}, referee={}", referral.getReferrerId(), refereeId);
    }

    @Transactional
    public void onRefereeFirstBookingCompleted(UUID refereeId) {
        referralRepository.findByRefereeId(refereeId).ifPresent(r -> {
            if (r.getStatus() == ReferralStatus.REGISTERED) {
                r.setStatus(ReferralStatus.EARNED);
                referralRepository.save(r);
                loyaltyPointService.earnPoints(r.getReferrerId(), PointSource.REFERRAL, r.getId(),
                        "Referral bonus: referee completed first booking");
                loyaltyPointService.earnPoints(refereeId, PointSource.REFERRAL, r.getId(),
                        "Referral bonus: completed first booking");
                log.info("Referral earned: referrer={}, referee={}", r.getReferrerId(), refereeId);
            }
        });
    }

    public Optional<ReferralEntity> getReferralByCode(String code) {
        return referralRepository.findAll().stream()
                .filter(r -> r.getReferralCode().equalsIgnoreCase(code))
                .findFirst();
    }
}
