package com.example.evstation.loyalty.application;

import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.loyalty.domain.PointSource;
import com.example.evstation.loyalty.domain.PointType;
import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyPointTransactionEntity;
import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyPointTransactionJpaRepository;
import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyUserProfileEntity;
import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyUserProfileJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class LoyaltyPointService {

    private final LoyaltyPointTransactionJpaRepository transactionRepository;
    private final LoyaltyUserProfileJpaRepository profileRepository;
    private final Clock clock;

    private static final int[] LEVEL_THRESHOLDS = {0, 100, 500, 1500, 5000, 15000};

    @Transactional
    public LoyaltyPointTransactionEntity earnPoints(UUID userId, PointSource source, UUID sourceId, String description) {
        return earnPoints(userId, source, sourceId, description, null);
    }

    @Transactional
    public LoyaltyPointTransactionEntity earnPoints(UUID userId, PointSource source, UUID sourceId,
                                                   String description, Map<String, Object> metadata) {
        if (sourceId != null && transactionRepository.countBySourceAndSourceId(source, sourceId) > 0) {
            log.info("Points already awarded for sourceId={}, skipping", sourceId);
            return null;
        }

        LoyaltyUserProfileEntity profile = profileRepository.findByUserId(userId)
                .orElseGet(() -> {
                    LoyaltyUserProfileEntity p = LoyaltyUserProfileEntity.builder()
                            .userId(userId)
                            .currentPoints(0)
                            .lifetimePoints(0)
                            .totalRatings(0)
                            .totalBookings(0)
                            .totalSwaps(0)
                            .totalContributions(0)
                            .level(1)
                            .build();
                    return profileRepository.save(p);
                });

        int points = source.getBasePoints();
        profile.setCurrentPoints(profile.getCurrentPoints() + points);
        profile.setLifetimePoints(profile.getLifetimePoints() + points);
        profile.setLastActivityAt(Instant.now(clock));
        profile.setLevel(calculateLevel(profile.getLifetimePoints()));
        profileRepository.save(profile);

        LoyaltyPointTransactionEntity tx = LoyaltyPointTransactionEntity.builder()
                .userId(userId)
                .type(PointType.EARN)
                .source(source)
                .sourceId(sourceId)
                .points(points)
                .balanceAfter(profile.getCurrentPoints())
                .description(description)
                .metadata(metadata)
                .build();
        tx = transactionRepository.save(tx);

        log.info("Earned {} points for userId={}, source={}, txId={}", points, userId, source, tx.getId());
        return tx;
    }

    @Transactional
    public LoyaltyPointTransactionEntity adjustPoints(UUID userId, int delta, String description) {
        LoyaltyUserProfileEntity profile = profileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(
                        ErrorCode.USER_NOT_FOUND, "User profile not found"));

        int newCurrent = profile.getCurrentPoints() + delta;
        if (newCurrent < 0) newCurrent = 0;
        profile.setCurrentPoints(newCurrent);
        profile.setLastActivityAt(Instant.now(clock));
        profileRepository.save(profile);

        LoyaltyPointTransactionEntity tx = LoyaltyPointTransactionEntity.builder()
                .userId(userId)
                .type(PointType.ADJUST)
                .source(PointSource.ADMIN_ADJUST)
                .points(delta)
                .balanceAfter(newCurrent)
                .description(description)
                .build();
        return transactionRepository.save(tx);
    }

    @Transactional
    public LoyaltyPointTransactionEntity redeemPoints(UUID userId, int amount, UUID redemptionId, String description) {
        LoyaltyUserProfileEntity profile = profileRepository.findByUserId(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.USER_NOT_FOUND, "User profile not found"));

        if (profile.getCurrentPoints() < amount) {
            throw new BusinessException(ErrorCode.INSUFFICIENT_POINTS,
                    String.format("Need %d points, have %d", amount, profile.getCurrentPoints()));
        }

        int newCurrent = profile.getCurrentPoints() - amount;
        profile.setCurrentPoints(newCurrent);
        profile.setLastActivityAt(Instant.now(clock));
        profileRepository.save(profile);

        LoyaltyPointTransactionEntity tx = LoyaltyPointTransactionEntity.builder()
                .userId(userId)
                .type(PointType.REDEEM)
                .source(PointSource.VOUCHER_REDEMPTION)
                .sourceId(redemptionId)
                .points(-amount)
                .balanceAfter(newCurrent)
                .description(description)
                .build();
        tx = transactionRepository.save(tx);

        log.info("Redeemed {} points for userId={}, redemptionId={}, txId={}", amount, userId, redemptionId, tx.getId());
        return tx;
    }

    @Transactional
    public void incrementBookingCount(UUID userId) {
        profileRepository.findByUserId(userId).ifPresent(p -> {
            p.setTotalBookings(p.getTotalBookings() + 1);
            profileRepository.save(p);
        });
    }

    @Transactional
    public void incrementSwapCount(UUID userId) {
        profileRepository.findByUserId(userId).ifPresent(p -> {
            p.setTotalSwaps(p.getTotalSwaps() + 1);
            profileRepository.save(p);
        });
    }

    @Transactional
    public void incrementRatingCount(UUID userId) {
        profileRepository.findByUserId(userId).ifPresent(p -> {
            p.setTotalRatings(p.getTotalRatings() + 1);
            profileRepository.save(p);
        });
    }

    @Transactional
    public void incrementContributionCount(UUID userId) {
        profileRepository.findByUserId(userId).ifPresent(p -> {
            p.setTotalContributions(p.getTotalContributions() + 1);
            profileRepository.save(p);
        });
    }

    public Optional<LoyaltyUserProfileEntity> getProfile(UUID userId) {
        return profileRepository.findByUserId(userId);
    }

    public Page<LoyaltyPointTransactionEntity> getHistory(UUID userId, Pageable pageable) {
        return transactionRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
    }

    public int calculateLevel(int lifetimePoints) {
        for (int i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
            if (lifetimePoints >= LEVEL_THRESHOLDS[i]) return i + 1;
        }
        return 1;
    }

    public String getLevelName(int level) {
        return switch (level) {
            case 1 -> "Bronze";
            case 2 -> "Silver";
            case 3 -> "Gold";
            case 4 -> "Platinum";
            case 5 -> "Diamond";
            default -> level > 5 ? "Master" : "Bronze";
        };
    }
}
