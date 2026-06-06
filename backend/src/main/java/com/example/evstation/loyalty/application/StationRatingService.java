package com.example.evstation.loyalty.application;

import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.loyalty.domain.*;
import com.example.evstation.loyalty.infrastructure.jpa.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class StationRatingService {

    private final StationRatingJpaRepository ratingRepository;
    private final RatingEligibilityJpaRepository eligibilityRepository;
    private final RatingEligibilityService eligibilityService;
    private final LoyaltyPointService loyaltyPointService;
    private final BadgeService badgeService;
    private final Clock clock;

    private static final int MAX_RATINGS_PER_DAY = 3;

    @Transactional
    public StationRatingEntity submitRating(UUID userId, UUID stationId, UUID eligibilityId,
                                           int rating, String comment,
                                           UUID sourceId, EligibilityType type, Instant eligibleAt) {
        if (rating < 1 || rating > 5) {
            throw new BusinessException(ErrorCode.INVALID_INPUT, "Rating must be between 1 and 5");
        }

        if (eligibilityId == null) {
            Optional<RatingEligibilityEntity> existing = eligibilityRepository
                    .findByUserIdAndStationIdAndSourceTypeAndSourceId(userId, stationId, type, sourceId);
            if (existing.isPresent()) {
                eligibilityId = existing.get().getId();
            }
        }

        long todayCount = ratingRepository.countTodayByUserId(userId, Instant.now(clock).minus(Duration.ofDays(1)));
        if (todayCount >= MAX_RATINGS_PER_DAY) {
            throw new BusinessException(ErrorCode.RATING_LIMIT_EXCEEDED,
                    "Daily rating limit (3/day) exceeded");
        }

        StationRatingEntity entity = StationRatingEntity.builder()
                .userId(userId)
                .stationId(stationId)
                .rating(rating)
                .comment(comment)
                .eligibilityId(eligibilityId)
                .isVerified(eligibilityId != null)
                .status(RatingStatus.ACTIVE)
                .build();
        entity = ratingRepository.save(entity);

        if (eligibilityId != null) {
            eligibilityService.markAsRated(eligibilityId);
        } else if (sourceId != null) {
            eligibilityService.markEligible(userId, stationId, sourceId, type, eligibleAt);
        }

        boolean hasComment = comment != null && comment.trim().length() >= 30;
        PointSource pointSource = hasComment ? PointSource.RATING_WITH_COMMENT : PointSource.RATING;
        loyaltyPointService.earnPoints(userId, pointSource, entity.getId(),
                String.format("Rated station %s: %d stars", stationId, rating));

        loyaltyPointService.incrementRatingCount(userId);

        var profile = loyaltyPointService.getProfile(userId);
        profile.ifPresent(p -> badgeService.checkAndAwardBadges(userId, BadgeCriteriaType.RATING_COUNT, p.getTotalRatings()));
        profile.ifPresent(p -> badgeService.checkAndAwardBadges(userId, BadgeCriteriaType.FIRST_RATING, p.getTotalRatings()));

        log.info("Rating submitted: userId={}, stationId={}, rating={}", userId, stationId, rating);
        return entity;
    }

    public Page<StationRatingEntity> getRatingsForStation(UUID stationId, Pageable pageable) {
        return ratingRepository.findByStationIdOrderByCreatedAtDesc(stationId, pageable);
    }

    public List<StationRatingEntity> getMyRatings(UUID userId) {
        return ratingRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public Optional<StationRatingEntity> getRatingById(UUID ratingId) {
        return ratingRepository.findById(ratingId);
    }

    @Transactional
    public void markHelpful(UUID ratingId, UUID voterId) {
        ratingRepository.findById(ratingId).ifPresent(r -> {
            r.setHelpfulCount(r.getHelpfulCount() + 1);
            ratingRepository.save(r);
        });
    }

    @Transactional
    public void hideRating(UUID ratingId) {
        ratingRepository.findById(ratingId).ifPresent(r -> {
            r.setStatus(RatingStatus.HIDDEN);
            ratingRepository.save(r);
        });
    }

    public StationRatingSummaryResult getRatingSummary(UUID stationId) {
        Double avg = ratingRepository.avgRatingByStationId(stationId, RatingStatus.ACTIVE);
        long total = ratingRepository.countActiveByStationId(stationId, RatingStatus.ACTIVE);
        List<Object[]> breakdown = ratingRepository.countByStationIdGroupByRating(stationId, RatingStatus.ACTIVE);

        int[] counts = new int[5];
        for (Object[] row : breakdown) {
            int star = (Integer) row[0];
            int count = ((Long) row[1]).intValue();
            if (star >= 1 && star <= 5) counts[star - 1] = count;
        }

        return new StationRatingSummaryResult(
                stationId,
                avg != null ? Math.round(avg * 10.0) / 10.0 : 0.0,
                (int) total,
                counts[0], counts[1], counts[2], counts[3], counts[4]
        );
    }

    public record StationRatingSummaryResult(
            UUID stationId,
            double averageRating,
            int totalRatings,
            int r1, int r2, int r3, int r4, int r5
    ) {}
}
