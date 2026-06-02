package com.example.evstation.risk.application;

import com.example.evstation.risk.domain.BatterySwapRiskReason;
import lombok.Builder;
import lombok.Getter;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Result of a battery swap risk assessment.
 * Contains the computed risk score, reasons, and flags for verification requirements.
 */
@Getter
@Builder
public class BatterySwapRiskAssessmentResult {

    private static final int MAX_SCORE = 100;
    private static final int MIN_SCORE = 0;

    /**
     * The computed risk score (0-100).
     */
    private final int riskScore;

    /**
     * List of risk reason codes that contributed to the score.
     */
    @Builder.Default
    private final List<BatterySwapRiskReason> riskReasons = new ArrayList<>();

    /**
     * Whether this request requires field verification.
     */
    private final boolean requiresVerification;

    /**
     * Whether this request requires admin review.
     */
    private final boolean requiresAdminReview;

    /**
     * Whether this request is auto-approvable (low risk).
     */
    private final boolean autoApprovable;

    /**
     * Risk level based on score.
     */
    private final String riskLevel;

    /**
     * Create result from a set of risk reasons.
     */
    public static BatterySwapRiskAssessmentResult fromReasons(Set<BatterySwapRiskReason> reasons) {
        int totalScore = reasons.stream()
                .mapToInt(BatterySwapRiskReason::getScoreContribution)
                .sum();

        int cappedScore = Math.min(totalScore, MAX_SCORE);

        boolean requiresVerification = cappedScore >= 20;
        boolean requiresAdminReview = cappedScore >= 50;
        boolean autoApprovable = cappedScore < 20;

        String riskLevel;
        if (cappedScore >= 50) {
            riskLevel = "HIGH";
        } else if (cappedScore >= 30) {
            riskLevel = "MEDIUM";
        } else if (cappedScore >= 10) {
            riskLevel = "LOW";
        } else {
            riskLevel = "MINIMAL";
        }

        return BatterySwapRiskAssessmentResult.builder()
                .riskScore(cappedScore)
                .riskReasons(new ArrayList<>(reasons))
                .requiresVerification(requiresVerification)
                .requiresAdminReview(requiresAdminReview)
                .autoApprovable(autoApprovable)
                .riskLevel(riskLevel)
                .build();
    }

    /**
     * Get the risk reasons as strings for JSON serialization.
     */
    public List<String> getRiskReasonCodes() {
        return riskReasons.stream()
                .map(Enum::name)
                .toList();
    }

    /**
     * Check if risk score is high (>= 50).
     */
    public boolean isHighRisk() {
        return riskScore >= 50;
    }

    /**
     * Check if risk score is medium (>= 30 and < 50).
     */
    public boolean isMediumRisk() {
        return riskScore >= 30 && riskScore < 50;
    }

    /**
     * Check if risk score is low (< 30).
     */
    public boolean isLowRisk() {
        return riskScore < 30;
    }
}
