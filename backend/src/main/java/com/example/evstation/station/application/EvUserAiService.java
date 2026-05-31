package com.example.evstation.station.application;

import com.example.evstation.api.ev_user_mobile.dto.RecommendationRequestDTO;
import com.example.evstation.api.ev_user_mobile.dto.RecommendationResponseDTO;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EvUserAiService {

    private final RecommendationQueryService recommendationQueryService;
    private final EntityManager entityManager;

    public Map<String, Object> getPersonalizedRecommendations(UUID userId, RecommendationRequestDTO request) {
        RecommendationResponseDTO base = recommendationQueryService.getRecommendations(request);
        Integer preferredHour = findPreferredHour(userId);
        String preferredPowerType = findPreferredPowerType(userId);

        List<Map<String, Object>> ranked = new ArrayList<>();
        for (RecommendationResponseDTO.RecommendationResultDTO result : base.getResults()) {
            int totalMinutes = result.getEstimate() != null && result.getEstimate().getTotalMinutes() != null
                    ? result.getEstimate().getTotalMinutes()
                    : 999;
            double score = Math.max(0, 100.0 - totalMinutes);
            List<String> reasons = new ArrayList<>();
            reasons.add("Base score from total travel+charge time");

            if (preferredPowerType != null
                    && result.getChosenPort() != null
                    && preferredPowerType.equalsIgnoreCase(result.getChosenPort().getPowerType())) {
                score += 8;
                reasons.add("Matched preferred power type: " + preferredPowerType);
            }

            if (preferredHour != null) {
                int nowHour = Instant.now().atZone(java.time.ZoneOffset.UTC).getHour();
                int hourDistance = Math.min(Math.abs(preferredHour - nowHour), 24 - Math.abs(preferredHour - nowHour));
                score += Math.max(0, 6 - hourDistance);
                reasons.add("Adjusted by preferred charging hour pattern");
            }

            Map<String, Object> item = new LinkedHashMap<>();
            item.put("stationId", result.getStationId());
            item.put("name", result.getName());
            item.put("address", result.getAddress());
            item.put("score", Math.round(score * 100.0) / 100.0);
            item.put("reasons", reasons);
            item.put("baseResult", result);
            ranked.add(item);
        }

        ranked.sort((a, b) -> Double.compare((double) b.get("score"), (double) a.get("score")));

        Map<String, Object> metadata = new LinkedHashMap<>();
        metadata.put("preferredHour", preferredHour);
        metadata.put("preferredPowerType", preferredPowerType);
        metadata.put("totalCandidates", ranked.size());

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("metadata", metadata);
        response.put("results", ranked.stream().limit(3).toList());
        return response;
    }

    public Map<String, Object> getSmartTimeSuggestions(
            UUID userId,
            UUID stationId,
            double distanceKm,
            int batteryPercent,
            int targetPercent,
            double batteryCapacityKwh,
            double avgTravelSpeedKmph) {
        int preferredHour = Optional.ofNullable(findPreferredHour(userId)).orElse(19);
        List<Map<String, Object>> suggestions = new ArrayList<>();
        Instant now = Instant.now();

        for (int i = 1; i <= 12; i++) {
            Instant slot = now.plus(i, ChronoUnit.HOURS);
            int load = findStationLoadAt(stationId, slot);
            double loadPenalty = Math.min(30, load * 6.0);
            double travelMinutes = (distanceKm / Math.max(5.0, avgTravelSpeedKmph)) * 60.0;
            double chargeMinutes = estimateChargeMinutes(batteryPercent, targetPercent, batteryCapacityKwh);
            int slotHour = slot.atZone(java.time.ZoneOffset.UTC).getHour();
            int preferenceDistance = Math.min(Math.abs(slotHour - preferredHour), 24 - Math.abs(slotHour - preferredHour));
            double preferenceBonus = Math.max(0, 8 - preferenceDistance);
            double score = Math.max(0, 100 - loadPenalty - (travelMinutes * 0.2) - (chargeMinutes * 0.1) + preferenceBonus);

            Map<String, Object> item = new LinkedHashMap<>();
            item.put("slotStart", slot);
            item.put("predictedLoad", load);
            item.put("estimatedTravelMinutes", Math.round(travelMinutes));
            item.put("estimatedChargeMinutes", Math.round(chargeMinutes));
            item.put("score", Math.round(score * 100.0) / 100.0);
            item.put("reason", List.of(
                    "Predicted slot load: " + load,
                    "Travel estimate: " + Math.round(travelMinutes) + " minutes",
                    "Charge estimate: " + Math.round(chargeMinutes) + " minutes"));
            suggestions.add(item);
        }

        suggestions.sort((a, b) -> Double.compare((double) b.get("score"), (double) a.get("score")));

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("stationId", stationId.toString());
        response.put("preferredHour", preferredHour);
        response.put("suggestions", suggestions.stream().limit(3).toList());
        return response;
    }

    private int findStationLoadAt(UUID stationId, Instant slot) {
        String sql = """
                SELECT COUNT(*) 
                FROM booking b
                WHERE b.station_id = :stationId
                  AND b.status IN ('HOLD','CONFIRMED')
                  AND b.start_time < :slotEnd
                  AND b.end_time > :slotStart
                """;
        Query query = entityManager.createNativeQuery(sql);
        query.setParameter("stationId", stationId);
        query.setParameter("slotStart", slot);
        query.setParameter("slotEnd", slot.plus(30, ChronoUnit.MINUTES));
        Number count = (Number) query.getSingleResult();
        return count != null ? count.intValue() : 0;
    }

    private Integer findPreferredHour(UUID userId) {
        String sql = """
                SELECT CAST(ROUND(AVG(EXTRACT(HOUR FROM b.start_time))) AS INTEGER)
                FROM booking b
                WHERE b.user_id = :userId
                  AND b.status IN ('CONFIRMED','CANCELLED','COMPLETED')
                """;
        Query query = entityManager.createNativeQuery(sql);
        query.setParameter("userId", userId);
        Number result = (Number) query.getSingleResult();
        return result == null ? null : result.intValue();
    }

    private String findPreferredPowerType(UUID userId) {
        String sql = """
                SELECT cu.power_type
                FROM booking b
                JOIN charger_unit cu ON cu.id = b.charger_unit_id
                WHERE b.user_id = :userId
                GROUP BY cu.power_type
                ORDER BY COUNT(*) DESC
                LIMIT 1
                """;
        Query query = entityManager.createNativeQuery(sql);
        query.setParameter("userId", userId);
        List<?> result = query.getResultList();
        return result.isEmpty() ? null : String.valueOf(result.get(0));
    }

    private double estimateChargeMinutes(int batteryPercent, int targetPercent, double batteryCapacityKwh) {
        if (targetPercent <= batteryPercent) {
            return 0;
        }
        double neededKwh = batteryCapacityKwh * (targetPercent - batteryPercent) / 100.0;
        double effectiveKw = targetPercent > 80 ? 30.0 : 45.0;
        return (neededKwh / effectiveKw) * 60.0;
    }
}
