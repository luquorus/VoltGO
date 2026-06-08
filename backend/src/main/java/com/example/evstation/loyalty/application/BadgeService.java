package com.example.evstation.loyalty.application;

import com.example.evstation.loyalty.api.dto.BadgeWithProgressDTO;
import com.example.evstation.loyalty.api.dto.UserBadgeDTO;
import com.example.evstation.loyalty.domain.BadgeCriteriaType;
import com.example.evstation.loyalty.domain.PointSource;
import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyBadgeJpaRepository;
import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyUserProfileJpaRepository;
import com.example.evstation.loyalty.infrastructure.jpa.UserBadgeEntity;
import com.example.evstation.loyalty.infrastructure.jpa.UserBadgeJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class BadgeService {

    private final LoyaltyBadgeJpaRepository badgeRepository;
    private final UserBadgeJpaRepository userBadgeRepository;
    private final LoyaltyUserProfileJpaRepository profileRepository;
    private final LoyaltyPointService loyaltyPointService;

    @Transactional
    public void checkAndAwardBadges(UUID userId, BadgeCriteriaType type, int currentValue) {
        List<com.example.evstation.loyalty.infrastructure.jpa.LoyaltyBadgeEntity> matchingBadges =
                badgeRepository.findByCriteriaTypeAndCriteriaValueLessThanOrEqual(type, currentValue);

        for (com.example.evstation.loyalty.infrastructure.jpa.LoyaltyBadgeEntity badge : matchingBadges) {
            if (!userBadgeRepository.existsByUserIdAndBadgeId(userId, badge.getId())) {
                UserBadgeEntity ub = UserBadgeEntity.builder()
                        .userId(userId)
                        .badgeId(badge.getId())
                        .build();
                userBadgeRepository.save(ub);

                if (badge.getPointsBonus() > 0) {
                    loyaltyPointService.earnPoints(userId, PointSource.BADGE, badge.getId(),
                            String.format("Earned badge: %s", badge.getName()));
                }
                log.info("Awarded badge {} to user {}", badge.getCode(), userId);
            }
        }
    }

    public List<UserBadgeDTO> getBadgesForUser(UUID userId) {
        return userBadgeRepository.findByUserId(userId).stream()
                .map(ub -> {
                    var badge = badgeRepository.findById(ub.getBadgeId()).orElse(null);
                    if (badge == null) return null;
                    return UserBadgeDTO.fromEntity(badge, ub.getEarnedAt());
                })
                .filter(b -> b != null)
                .toList();
    }

    public List<BadgeWithProgressDTO> getAllBadgesWithProgress(UUID userId) {
        Integer bookings = null, swaps = null, contributions = null, ratings = null, lifetime = null;
        if (userId != null) {
            var profile = profileRepository.findByUserId(userId).orElse(null);
            if (profile != null) {
                bookings = profile.getTotalBookings();
                swaps = profile.getTotalSwaps();
                contributions = profile.getTotalContributions();
                ratings = profile.getTotalRatings();
                lifetime = profile.getLifetimePoints();
            }
        }
        int b = bookings != null ? bookings : 0;
        int s = swaps != null ? swaps : 0;
        int c = contributions != null ? contributions : 0;
        int r = ratings != null ? ratings : 0;
        int l = lifetime != null ? lifetime : 0;

        var earnedBadgeIds = userBadgeRepository.findByUserId(userId).stream()
                .map(UserBadgeEntity::getBadgeId)
                .toList();

        return badgeRepository.findAll().stream()
                .map(badge -> {
                    int current = switch (badge.getCriteriaType()) {
                        case BOOKING_COUNT -> b;
                        case SWAP_COUNT -> s;
                        case CR_COUNT -> c;
                        case RATING_COUNT -> r;
                        case POINTS_MILESTONE -> l;
                        case FIRST_BOOKING, FIRST_SWAP, FIRST_RATING -> 1;
                        default -> 0;
                    };
                    boolean earned = earnedBadgeIds.contains(badge.getId());
                    return BadgeWithProgressDTO.builder()
                            .id(badge.getId().toString())
                            .code(badge.getCode())
                            .name(badge.getName())
                            .tier(badge.getTier().name())
                            .description(badge.getDescription())
                            .icon(badge.getIcon())
                            .currentValue(current)
                            .targetValue(badge.getCriteriaValue())
                            .pointsBonus(badge.getPointsBonus())
                            .isEarned(earned)
                            .build();
                })
                .toList();
    }
}
