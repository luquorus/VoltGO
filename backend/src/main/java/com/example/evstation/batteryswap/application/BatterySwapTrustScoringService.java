package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapTrustEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapTrustJpaRepository;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Service for calculating and updating battery swap trust scores.
 * 
 * Trust score is based on 6 dimensions (each 0-20 pts, total 120 pts possible):
 * 1. Accuracy Trust - Consistency between declared and verified inventory
 * 2. Reliability Trust - SLA compliance, equipment uptime
 * 3. Safety Trust - Battery certification, temperature control
 * 4. Fairness Trust - Swap pricing, no surge pricing
 * 5. Completeness Trust - Photo evidence, data completeness
 * 6. Compliance Trust - Regulatory compliance, permits
 * 
 * Initial score: 50 points (neutral baseline)
 * Final score = clamp(base + dimension scores, 0, 100)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BatterySwapTrustScoringService {

    private static final int INITIAL_SCORE = 50;
    private static final int MAX_DIMENSION_SCORE = 20;
    
    // Dimension constants
    private static final String DIM_ACCURACY = "accuracy";
    private static final String DIM_RELIABILITY = "reliability";
    private static final String DIM_SAFETY = "safety";
    private static final String DIM_FAIRNESS = "fairness";
    private static final String DIM_COMPLETENESS = "completeness";
    private static final String DIM_COMPLIANCE = "compliance";
    
    // Adjustment values
    private static final int VERIFIED_BONUS = 10;
    private static final int INVENTORY_ACCURATE_BONUS = 5;
    private static final int VERIFICATION_FAIL_PENALTY = -10;
    
    private final BatterySwapTrustJpaRepository trustRepository;
    private final Clock clock;
    
    /**
     * Initialize trust record for a new battery swap station.
     * Creates BatterySwapTrustEntity with initial score of 50 and empty breakdown.
     * 
     * @param stationId The station ID
     * @return The created trust entity
     */
    @Transactional
    public BatterySwapTrustEntity initializeForStation(UUID stationId) {
        log.info("Initializing trust for battery swap station: {}", stationId);
        
        if (trustRepository.existsByStationId(stationId)) {
            log.warn("Trust record already exists for station: {}", stationId);
            return trustRepository.findByStationId(stationId).orElse(null);
        }
        
        Map<String, Integer> initialBreakdown = createInitialBreakdown();
        
        BatterySwapTrustEntity trust = BatterySwapTrustEntity.builder()
                .id(UUID.randomUUID())
                .stationId(stationId)
                .score(INITIAL_SCORE)
                .breakdown(initialBreakdown)
                .lastEventAt(Instant.now(clock))
                .createdAt(Instant.now(clock))
                .updatedAt(Instant.now(clock))
                .build();
        
        trustRepository.save(trust);
        log.info("Created BatterySwapTrustEntity: stationId={}, score={}", stationId, INITIAL_SCORE);
        
        return trust;
    }
    
    /**
     * Initialize trust and return as DTO.
     */
    @Transactional
    public BatterySwapTrustScoreDTO initializeForStationAsDTO(UUID stationId) {
        BatterySwapTrustEntity entity = initializeForStation(stationId);
        if (entity == null) {
            entity = trustRepository.findByStationId(stationId).orElse(null);
        }
        if (entity == null) {
            throw new IllegalStateException("Failed to initialize trust for station: " + stationId);
        }
        return toDTO(entity);
    }
    
    /**
     * Calculate and update trust score based on verification review.
     * Updates accuracy dimension based on review results.
     * 
     * @param stationId The station ID
     * @param review The verification review entity
     * @return The updated trust entity, or empty if not found
     */
    @Transactional
    public Optional<BatterySwapTrustEntity> calculateAndUpdateTrust(UUID stationId, VerificationReviewEntity review) {
        log.info("Calculating trust update for station: {}, reviewResult={}", stationId, review.getResult());
        
        Optional<BatterySwapTrustEntity> optTrust = trustRepository.findByStationId(stationId);
        if (optTrust.isEmpty()) {
            log.warn("No trust record found for station: {}, initializing first", stationId);
            initializeForStation(stationId);
            optTrust = trustRepository.findByStationId(stationId);
        }
        
        BatterySwapTrustEntity trust = optTrust.orElse(null);
        if (trust == null) {
            return Optional.empty();
        }
        
        Map<String, Integer> breakdown = trust.getBreakdown();
        if (breakdown == null) {
            breakdown = createInitialBreakdown();
        }
        
        // Update accuracy dimension based on verification
        int accuracyScore = breakdown.getOrDefault(DIM_ACCURACY, 0);
        int newAccuracyScore = accuracyScore;
        
        if (review.getSwapStationVerified() != null && review.getSwapStationVerified()) {
            newAccuracyScore += VERIFIED_BONUS;
        }
        if (review.getInventoryAccurate() != null && review.getInventoryAccurate()) {
            newAccuracyScore += INVENTORY_ACCURATE_BONUS;
        }
        if (review.getResult() == com.example.evstation.verification.domain.VerificationResult.FAIL) {
            newAccuracyScore += VERIFICATION_FAIL_PENALTY;
        }
        
        // Cap at max dimension score
        newAccuracyScore = Math.max(0, Math.min(MAX_DIMENSION_SCORE, newAccuracyScore));
        breakdown.put(DIM_ACCURACY, newAccuracyScore);
        
        // Recalculate total score
        int totalScore = INITIAL_SCORE + breakdown.values().stream().mapToInt(Integer::intValue).sum();
        int clampedScore = Math.max(0, Math.min(100, totalScore));
        
        trust.setScore(clampedScore);
        trust.setBreakdown(breakdown);
        trust.setLastEventAt(Instant.now(clock));
        trust.setUpdatedAt(Instant.now(clock));
        
        trustRepository.save(trust);
        
        log.info("Trust updated: stationId={}, score={}, accuracy={}->{}", 
                stationId, clampedScore, accuracyScore, newAccuracyScore);
        
        return Optional.of(trust);
    }
    
    /**
     * Calculate and update trust returning DTO.
     */
    @Transactional
    public BatterySwapTrustScoreDTO calculateAndUpdateTrustAsDTO(UUID stationId, VerificationReviewEntity review) {
        Optional<BatterySwapTrustEntity> result = calculateAndUpdateTrust(stationId, review);
        return result.map(this::toDTO)
                .orElseThrow(() -> new IllegalStateException("Failed to update trust for station: " + stationId));
    }
    
    /**
     * Get trust score for a station.
     * 
     * @param stationId The station ID
     * @return The trust score (0-100), or empty if no trust record exists
     */
    @Transactional(readOnly = true)
    public Optional<Integer> getTrustScore(UUID stationId) {
        return trustRepository.findByStationId(stationId)
                .map(BatterySwapTrustEntity::getScore);
    }
    
    /**
     * Get trust score as DTO.
     */
    @Transactional(readOnly = true)
    public Optional<BatterySwapTrustScoreDTO> getTrustScoreAsDTO(UUID stationId) {
        return trustRepository.findByStationId(stationId)
                .map(this::toDTO);
    }
    
    /**
     * Get full trust entity for a station.
     * 
     * @param stationId The station ID
     * @return The trust entity, or empty if not found
     */
    @Transactional(readOnly = true)
    public Optional<BatterySwapTrustEntity> getTrustEntity(UUID stationId) {
        return trustRepository.findByStationId(stationId);
    }
    
    /**
     * Get trust breakdown by dimension.
     * 
     * @param stationId The station ID
     * @return Map of dimension names to scores, or empty if no trust record exists
     */
    @Transactional(readOnly = true)
    public Optional<Map<String, Integer>> getTrustBreakdown(UUID stationId) {
        return trustRepository.findByStationId(stationId)
                .map(BatterySwapTrustEntity::getBreakdown);
    }
    
    /**
     * Get trust level based on score.
     * 
     * @param stationId The station ID
     * @return Trust level: HIGH (>=70), MEDIUM (30-69), LOW (<30), or null if no record
     */
    @Transactional(readOnly = true)
    public Optional<String> getTrustLevel(UUID stationId) {
        return trustRepository.findByStationId(stationId)
                .map(BatterySwapTrustEntity::getTrustLevel);
    }
    
    /**
     * Full recalculation of trust score from historical data.
     * This should be called when:
     * - A significant event occurs that requires full recalculation
     * - Trust score appears out of sync
     * 
     * @param stationId The station ID
     * @return The recalculated trust entity, or empty if not found
     */
    @Transactional
    public Optional<BatterySwapTrustEntity> recalculate(UUID stationId) {
        log.info("Full trust recalculation for station: {}", stationId);
        
        Optional<BatterySwapTrustEntity> optTrust = trustRepository.findByStationId(stationId);
        if (optTrust.isEmpty()) {
            log.info("No trust record found for station: {}, creating initial record", stationId);
            return Optional.of(initializeForStation(stationId));
        }
        
        BatterySwapTrustEntity trust = optTrust.get();
        Map<String, Integer> breakdown = trust.getBreakdown();
        
        // Ensure all dimensions exist
        if (breakdown == null || breakdown.isEmpty()) {
            breakdown = createInitialBreakdown();
        }
        
        // Ensure all dimensions are present
        ensureAllDimensions(breakdown);
        
        // Recalculate total score
        int totalScore = INITIAL_SCORE + breakdown.values().stream().mapToInt(Integer::intValue).sum();
        int clampedScore = Math.max(0, Math.min(100, totalScore));
        
        trust.setScore(clampedScore);
        trust.setBreakdown(breakdown);
        trust.setUpdatedAt(Instant.now(clock));
        
        trustRepository.save(trust);
        
        log.info("Trust recalculated: stationId={}, score={}, breakdown={}", 
                stationId, clampedScore, breakdown);
        
        return Optional.of(trust);
    }
    
    /**
     * Recalculate and return as DTO.
     */
    @Transactional
    public BatterySwapTrustScoreDTO recalculateAsDTO(UUID stationId) {
        Optional<BatterySwapTrustEntity> result = recalculate(stationId);
        return result.map(this::toDTO)
                .orElseThrow(() -> new IllegalStateException("Failed to recalculate trust for station: " + stationId));
    }
    
    /**
     * Update a specific dimension of the trust breakdown.
     * 
     * @param stationId The station ID
     * @param dimension The dimension to update
     * @param delta The change in score (can be positive or negative)
     * @return The updated trust entity, or empty if not found
     */
    @Transactional
    public Optional<BatterySwapTrustEntity> updateDimension(UUID stationId, String dimension, int delta) {
        log.info("Updating dimension {} for station: {} with delta {}", dimension, stationId, delta);
        
        Optional<BatterySwapTrustEntity> optTrust = trustRepository.findByStationId(stationId);
        if (optTrust.isEmpty()) {
            log.warn("Cannot update dimension: no trust record for station: {}", stationId);
            return Optional.empty();
        }
        
        BatterySwapTrustEntity trust = optTrust.get();
        Map<String, Integer> breakdown = trust.getBreakdown();
        
        if (!isValidDimension(dimension)) {
            log.warn("Invalid dimension: {}", dimension);
            return Optional.empty();
        }
        
        int currentScore = breakdown.getOrDefault(dimension, 0);
        int newScore = Math.max(0, Math.min(MAX_DIMENSION_SCORE, currentScore + delta));
        breakdown.put(dimension, newScore);
        
        // Recalculate total
        int totalScore = INITIAL_SCORE + breakdown.values().stream().mapToInt(Integer::intValue).sum();
        int clampedScore = Math.max(0, Math.min(100, totalScore));
        
        trust.setScore(clampedScore);
        trust.setBreakdown(breakdown);
        trust.setLastEventAt(Instant.now(clock));
        trust.setUpdatedAt(Instant.now(clock));
        
        trustRepository.save(trust);
        
        log.info("Dimension updated: stationId={}, dimension={}, {}{}", 
                stationId, dimension, delta >= 0 ? "+" : "", delta);
        
        return Optional.of(trust);
    }
    
    // ========== Private helper methods ==========
    
    private BatterySwapTrustScoreDTO toDTO(BatterySwapTrustEntity entity) {
        String level;
        if (entity.getScore() >= 90) level = "EXCELLENT";
        else if (entity.getScore() >= 70) level = "GOOD";
        else if (entity.getScore() >= 50) level = "FAIR";
        else if (entity.getScore() > 0) level = "POOR";
        else level = "NEW";

        return new BatterySwapTrustScoreDTO(
                entity.getStationId(),
                entity.getScore(),
                entity.getBreakdown() != null ? entity.getBreakdown() : createInitialBreakdown(),
                entity.getUpdatedAt(),
                level
        );
    }
    
    private Map<String, Integer> createInitialBreakdown() {
        Map<String, Integer> breakdown = new HashMap<>();
        breakdown.put(DIM_ACCURACY, 0);
        breakdown.put(DIM_RELIABILITY, 0);
        breakdown.put(DIM_SAFETY, 0);
        breakdown.put(DIM_FAIRNESS, 0);
        breakdown.put(DIM_COMPLETENESS, 0);
        breakdown.put(DIM_COMPLIANCE, 0);
        return breakdown;
    }
    
    private void ensureAllDimensions(Map<String, Integer> breakdown) {
        breakdown.putIfAbsent(DIM_ACCURACY, 0);
        breakdown.putIfAbsent(DIM_RELIABILITY, 0);
        breakdown.putIfAbsent(DIM_SAFETY, 0);
        breakdown.putIfAbsent(DIM_FAIRNESS, 0);
        breakdown.putIfAbsent(DIM_COMPLETENESS, 0);
        breakdown.putIfAbsent(DIM_COMPLIANCE, 0);
    }
    
    private boolean isValidDimension(String dimension) {
        return DIM_ACCURACY.equals(dimension) ||
               DIM_RELIABILITY.equals(dimension) ||
               DIM_SAFETY.equals(dimension) ||
               DIM_FAIRNESS.equals(dimension) ||
               DIM_COMPLETENESS.equals(dimension) ||
               DIM_COMPLIANCE.equals(dimension);
    }
}
