package com.example.evstation.risk.domain;

import lombok.Builder;
import lombok.Getter;

import java.util.ArrayList;
import java.util.List;

/**
 * Domain model representing the result of a risk assessment for a change request.
 * Contains the computed risk score and the list of reasons that contributed to it.
 */
@Getter
@Builder
public class RiskAssessment {
    
    private static final int MAX_SCORE = 100;
    private static final int MIN_SCORE = 0;
    
    /**
     * The computed risk score (0-100).
     * Higher scores indicate higher risk changes.
     */
    private final int riskScore;
    
    /**
     * List of reason codes that contributed to the risk score.
     * Provides explainability for the risk assessment.
     */
    @Builder.Default
    private final List<RiskReasonCode> riskReasons = new ArrayList<>();
    
    /**
     * Create a RiskAssessment from a list of reason codes.
     * Automatically computes the score based on the reasons.
     */
    public static RiskAssessment fromReasons(List<RiskReasonCode> reasons) {
        int totalScore = reasons.stream()
                .mapToInt(RiskReasonCode::getScoreContribution)
                .sum();
        
        // Cap the score at MAX_SCORE
        int cappedScore = Math.min(totalScore, MAX_SCORE);
        
        return RiskAssessment.builder()
                .riskScore(cappedScore)
                .riskReasons(new ArrayList<>(reasons))
                .build();
    }
    
    /**
     * Create an empty RiskAssessment (no risk).
     */
    public static RiskAssessment noRisk() {
        return RiskAssessment.builder()
                .riskScore(MIN_SCORE)
                .riskReasons(new ArrayList<>())
                .build();
    }
    
    /**
     * Check if this assessment indicates high risk (score >= 50).
     */
    public boolean isHighRisk() {
        return riskScore >= 50;
    }
    
    /**
     * Check if this assessment indicates medium risk (score >= 30 and < 50).
     */
    public boolean isMediumRisk() {
        return riskScore >= 30 && riskScore < 50;
    }
    
    /**
     * Check if this assessment indicates low risk (score < 30).
     */
    public boolean isLowRisk() {
        return riskScore < 30;
    }
    
    /**
     * Get the risk level as a string.
     */
    public String getRiskLevel() {
        if (isHighRisk()) return "HIGH";
        if (isMediumRisk()) return "MEDIUM";
        return "LOW";
    }
    
    /**
     * Get the reason codes as a list of strings (for JSON serialization).
     */
    public List<String> getRiskReasonCodes() {
        return riskReasons.stream()
                .map(RiskReasonCode::name)
                .toList();
    }
}

