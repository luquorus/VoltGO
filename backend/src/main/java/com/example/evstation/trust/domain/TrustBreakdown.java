package com.example.evstation.trust.domain;

import lombok.Builder;
import lombok.Data;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Domain model representing the breakdown of a trust score.
 * Each component is explained with its contribution to the final score.
 */
@Data
@Builder
public class TrustBreakdown {
    
    /** Base score when station is first published (50) */
    private int base;
    
    /** Verification bonus/penalty (+20 PASS, -20 FAIL within 30 days) */
    private int verificationBonus;
    
    /** Penalty for unresolved issues (-5 per issue, max -30) */
    private int issuesPenalty;
    
    /** Penalty for high-risk change requests in last 30 days (-10) */
    private int highRiskPenalty;
    
    /**
     * Calculate the final trust score from all components.
     * Score is clamped between 0 and 100.
     */
    public int calculateScore() {
        int raw = base + verificationBonus + issuesPenalty + highRiskPenalty;
        return Math.max(0, Math.min(100, raw));
    }
    
    /**
     * Convert breakdown to JSON-compatible map for storage.
     */
    public Map<String, Object> toMap() {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("base", base);
        map.put("verification_bonus", verificationBonus);
        map.put("issues_penalty", issuesPenalty);
        map.put("high_risk_penalty", highRiskPenalty);
        return map;
    }
    
    /**
     * Create TrustBreakdown from stored map.
     */
    public static TrustBreakdown fromMap(Map<String, Object> map) {
        return TrustBreakdown.builder()
                .base(getInt(map, "base", 50))
                .verificationBonus(getInt(map, "verification_bonus", 0))
                .issuesPenalty(getInt(map, "issues_penalty", 0))
                .highRiskPenalty(getInt(map, "high_risk_penalty", 0))
                .build();
    }
    
    private static int getInt(Map<String, Object> map, String key, int defaultValue) {
        Object value = map.get(key);
        if (value instanceof Number) {
            return ((Number) value).intValue();
        }
        return defaultValue;
    }
}

