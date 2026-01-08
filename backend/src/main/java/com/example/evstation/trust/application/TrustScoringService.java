package com.example.evstation.trust.application;

import com.example.evstation.station.domain.ChangeRequestStatus;
import com.example.evstation.station.infrastructure.jpa.ChangeRequestEntity;
import com.example.evstation.station.infrastructure.jpa.ChangeRequestJpaRepository;
import com.example.evstation.station.infrastructure.jpa.ReportIssueEntity;
import com.example.evstation.station.infrastructure.jpa.ReportIssueJpaRepository;
import com.example.evstation.trust.domain.TrustBreakdown;
import com.example.evstation.trust.infrastructure.jpa.StationTrustEntity;
import com.example.evstation.trust.infrastructure.jpa.StationTrustJpaRepository;
import com.example.evstation.verification.domain.VerificationResult;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Service for calculating and updating station trust scores.
 * 
 * Trust score rules (Phase 1):
 * - Base: 50 points when station is first published
 * - Verification: +20 for PASS, -20 for FAIL (within 30 days)
 * - Issues: -5 per OPEN/ACKNOWLEDGED issue (max -30)
 * - High Risk: -10 if any published CR in 30 days with risk_score >= 60
 * 
 * Final score = clamp(base + bonuses + penalties, 0, 100)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TrustScoringService {
    
    private static final int BASE_SCORE = 50;
    private static final int VERIFICATION_PASS_BONUS = 20;
    private static final int VERIFICATION_FAIL_PENALTY = -20;
    private static final int ISSUE_PENALTY_PER_ISSUE = -5;
    private static final int MAX_ISSUE_PENALTY = -30;
    private static final int HIGH_RISK_PENALTY = -10;
    private static final int HIGH_RISK_THRESHOLD = 60;
    private static final int LOOKBACK_DAYS = 30;
    
    private final StationTrustJpaRepository trustRepository;
    private final ReportIssueJpaRepository issueRepository;
    private final ChangeRequestJpaRepository changeRequestRepository;
    private final VerificationReviewJpaRepository verificationReviewRepository;
    private final Clock clock;
    
    /**
     * Recalculate trust score for a station.
     * This should be called when:
     * - Station is first published
     * - Admin reviews verification (PASS/FAIL)
     * - Issue is created or status changes
     * 
     * @param stationId The station ID to recalculate
     * @return The updated trust score
     */
    @Transactional
    public int recalculate(UUID stationId) {
        log.info("Recalculating trust score for station: {}", stationId);
        
        Instant now = Instant.now(clock);
        Instant thirtyDaysAgo = now.minus(LOOKBACK_DAYS, ChronoUnit.DAYS);
        
        // Calculate each component
        int base = BASE_SCORE;
        int verificationBonus = calculateVerificationBonus(stationId, thirtyDaysAgo);
        int issuesPenalty = calculateIssuesPenalty(stationId);
        int highRiskPenalty = calculateHighRiskPenalty(stationId, thirtyDaysAgo);
        
        TrustBreakdown breakdown = TrustBreakdown.builder()
                .base(base)
                .verificationBonus(verificationBonus)
                .issuesPenalty(issuesPenalty)
                .highRiskPenalty(highRiskPenalty)
                .build();
        
        int score = breakdown.calculateScore();
        
        // Persist the trust score
        StationTrustEntity trustEntity = trustRepository.findById(stationId)
                .orElse(StationTrustEntity.builder()
                        .stationId(stationId)
                        .build());
        
        trustEntity.setScore(score);
        trustEntity.setBreakdown(breakdown.toMap());
        trustEntity.setUpdatedAt(now);
        
        trustRepository.save(trustEntity);
        
        log.info("Trust score updated: stationId={}, score={}, breakdown={}", 
                stationId, score, breakdown.toMap());
        
        return score;
    }
    
    /**
     * Get current trust score for a station.
     * Returns null if no trust score exists.
     */
    @Transactional(readOnly = true)
    public Optional<Integer> getTrustScore(UUID stationId) {
        return trustRepository.findById(stationId)
                .map(StationTrustEntity::getScore);
    }
    
    /**
     * Get full trust breakdown for a station.
     */
    @Transactional(readOnly = true)
    public Optional<TrustBreakdown> getTrustBreakdown(UUID stationId) {
        return trustRepository.findById(stationId)
                .map(entity -> TrustBreakdown.fromMap(entity.getBreakdown()));
    }
    
    /**
     * Get trust entity with full details.
     */
    @Transactional(readOnly = true)
    public Optional<StationTrustEntity> getTrustEntity(UUID stationId) {
        return trustRepository.findById(stationId);
    }
    
    // ========== Private calculation methods ==========
    
    /**
     * Calculate verification bonus/penalty.
     * Check if last verification within 30 days was PASS (+20) or FAIL (-20)
     */
    private int calculateVerificationBonus(UUID stationId, Instant since) {
        List<VerificationReviewEntity> recentReviews = 
                verificationReviewRepository.findRecentReviewsForStation(stationId, since);
        
        if (recentReviews.isEmpty()) {
            return 0;
        }
        
        // Get the most recent review
        VerificationReviewEntity latestReview = recentReviews.get(0);
        
        if (latestReview.getResult() == VerificationResult.PASS) {
            return VERIFICATION_PASS_BONUS;
        } else {
            return VERIFICATION_FAIL_PENALTY;
        }
    }
    
    /**
     * Calculate penalty for unresolved issues.
     * -5 per OPEN/ACKNOWLEDGED issue, max -30.
     */
    private int calculateIssuesPenalty(UUID stationId) {
        List<ReportIssueEntity> unresolvedIssues = issueRepository.findUnresolvedByStationId(stationId);
        int count = unresolvedIssues.size();
        
        int penalty = count * ISSUE_PENALTY_PER_ISSUE;
        return Math.max(penalty, MAX_ISSUE_PENALTY);
    }
    
    /**
     * Calculate penalty for high-risk change requests.
     * -10 if any published CR in last 30 days has risk_score >= 60.
     */
    private int calculateHighRiskPenalty(UUID stationId, Instant since) {
        List<ChangeRequestEntity> recentCRs = changeRequestRepository.findByStationIdOrderByCreatedAtDesc(stationId);
        
        boolean hasHighRisk = recentCRs.stream()
                .filter(cr -> cr.getStatus() == ChangeRequestStatus.PUBLISHED)
                .filter(cr -> cr.getDecidedAt() != null && cr.getDecidedAt().isAfter(since))
                .anyMatch(cr -> cr.getRiskScore() >= HIGH_RISK_THRESHOLD);
        
        return hasHighRisk ? HIGH_RISK_PENALTY : 0;
    }
}

