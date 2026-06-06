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
        log.info("REFERRAL_SERVICE: onReferralSignup called with code='{}', refereeId={}", referralCode, refereeId);
        var allReferrals = referralRepository.findAll().stream()
                .filter(r -> r.getReferralCode().equalsIgnoreCase(referralCode))
                .toList();
        log.info("REFERRAL_SERVICE: Found {} referral(s) matching code '{}'", allReferrals.size(), referralCode);
        if (allReferrals.isEmpty()) return;
        ReferralEntity referral = allReferrals.get(0);
        log.info("REFERRAL_SERVICE: Matching referral found - referrerId={}, existingRefereeId={}, status={}",
                referral.getReferrerId(), referral.getRefereeId(), referral.getStatus());
        if (referral.getRefereeId() != null) return;
        referral.setRefereeId(refereeId);
        referral.setStatus(ReferralStatus.REGISTERED);
        referralRepository.save(referral);
        log.info("REFERRAL_SERVICE: Referral registered - referrer={}, referee={}", referral.getReferrerId(), refereeId);
    }

    @Transactional
    public void onRefereeFirstBookingCompleted(UUID refereeId) {
        referralRepository.findByRefereeId(refereeId).ifPresent(r -> {
            if (r.getStatus() == ReferralStatus.REGISTERED) {
                r.setStatus(ReferralStatus.EARNED);
                referralRepository.save(r);
                // Referrer earns: use referral record ID as sourceId
                loyaltyPointService.earnPoints(r.getReferrerId(), PointSource.REFERRAL, r.getId(),
                        "Referral bonus: referee completed first booking");
                // Referee earns: use referral record ID + referee ID composite as sourceId
                // to avoid duplicate detection (same referral ID was used for referrer)
                UUID refereeSourceId = UUID.nameUUIDFromBytes(
                        (r.getId().toString() + "_referee_" + refereeId.toString()).getBytes());
                loyaltyPointService.earnPoints(refereeId, PointSource.REFERRAL, refereeSourceId,
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
