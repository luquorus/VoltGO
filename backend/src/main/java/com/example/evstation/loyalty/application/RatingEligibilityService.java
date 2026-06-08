package com.example.evstation.loyalty.application;

import com.example.evstation.loyalty.domain.EligibilityType;
import com.example.evstation.loyalty.infrastructure.jpa.RatingEligibilityEntity;
import com.example.evstation.loyalty.infrastructure.jpa.RatingEligibilityJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class RatingEligibilityService {

    private final RatingEligibilityJpaRepository eligibilityRepository;

    @Transactional
    public void markEligible(UUID userId, UUID stationId, UUID sourceId, EligibilityType type, Instant eligibleAt) {
        if (eligibilityRepository.existsByUserIdAndStationIdAndSourceTypeAndSourceId(
                userId, stationId, type, sourceId)) {
            return;
        }
        RatingEligibilityEntity e = RatingEligibilityEntity.builder()
                .userId(userId)
                .stationId(stationId)
                .sourceType(type)
                .sourceId(sourceId)
                .eligibleAt(eligibleAt)
                .isRated(false)
                .build();
        eligibilityRepository.save(e);
        log.info("Marked eligible: userId={}, stationId={}, type={}", userId, stationId, type);
    }

    @Transactional
    public void markEligibleFromCR(UUID userId, UUID stationId, UUID crId, Instant publishedAt) {
        markEligible(userId, stationId, crId, EligibilityType.INFO_CONTRIBUTION, publishedAt);
    }

    public List<RatingEligibilityEntity> getUnratedEligibleStations(UUID userId) {
        return eligibilityRepository.findByUserIdAndIsRatedFalse(userId);
    }

    @Transactional
    public void markAsRated(UUID eligibilityId) {
        eligibilityRepository.findById(eligibilityId).ifPresent(e -> {
            e.setIsRated(true);
            eligibilityRepository.save(e);
        });
    }
}
