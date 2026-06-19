package com.example.evstation.batteryswapchange.web;

import com.example.evstation.batteryswap.application.BatterySwapTrustScoreDTO;
import com.example.evstation.batteryswap.application.BatterySwapTrustScoringService;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapTrustEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapTrustJpaRepository;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewJpaRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Tag(name = "Battery Swap Trust", description = "API for battery swap station trust scores (read: public; mutate/history: ADMIN)")
@RestController
@RequestMapping("/api/v1/battery-swap/trust")
@RequiredArgsConstructor
public class BatterySwapTrustController {

    private final BatterySwapTrustScoringService trustScoringService;
    private final BatterySwapTrustJpaRepository trustRepository;
    private final VerificationReviewJpaRepository reviewRepository;
    private final StationVersionJpaRepository stationVersionRepository;

    @Operation(
            summary = "Get trust score for a battery swap station",
            description = "Public. Returns the trust score DTO for the specified station ID."
    )
    @GetMapping("/{stationId}")
    public ResponseEntity<BatterySwapTrustScoreDTO> getTrustScore(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {

        log.info("Getting trust score for station: {}", stationId);

        return trustScoringService.getTrustScoreAsDTO(stationId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
            summary = "Get trust breakdown by dimension",
            description = "Public. Returns the trust score breakdown by dimension (accuracy, reliability, safety, etc.)"
    )
    @GetMapping("/{stationId}/breakdown")
    public ResponseEntity<Map<String, Integer>> getTrustBreakdown(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {

        log.info("Getting trust breakdown for station: {}", stationId);

        return trustScoringService.getTrustBreakdown(stationId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
            summary = "Get trust level",
            description = "Public. Returns the trust level (HIGH if score >= 70, MEDIUM if 30-69, LOW if < 30)"
    )
    @GetMapping("/{stationId}/level")
    public ResponseEntity<String> getTrustLevel(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {

        log.info("Getting trust level for station: {}", stationId);

        return trustScoringService.getTrustLevel(stationId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @Operation(
            summary = "Get trust summary across all battery swap stations",
            description = "Public. Returns aggregate trust statistics: total stations, counts by level, average score, top/bottom stations."
    )
    @GetMapping("/summary")
    public ResponseEntity<Map<String, Object>> getTrustSummary() {
        log.info("Getting battery swap trust summary");

        List<BatterySwapTrustEntity> all = trustRepository.findAll();
        Map<String, Object> summary = new LinkedHashMap<>();

        if (all.isEmpty()) {
            summary.put("totalStations", 0);
            summary.put("excellentCount", 0);
            summary.put("goodCount", 0);
            summary.put("fairCount", 0);
            summary.put("poorCount", 0);
            summary.put("newCount", 0);
            summary.put("highCount", 0);
            summary.put("mediumCount", 0);
            summary.put("lowCount", 0);
            summary.put("averageScore", 0.0);
            summary.put("topStations", Collections.emptyList());
            summary.put("bottomStations", Collections.emptyList());
            return ResponseEntity.ok(summary);
        }

        double avg = all.stream()
                .mapToInt(BatterySwapTrustEntity::getScore)
                .average()
                .orElse(0.0);

        int excellent = 0, good = 0, fair = 0, poor = 0, newCount = 0;
        for (BatterySwapTrustEntity t : all) {
            if (t.getScore() >= 90) excellent++;
            else if (t.getScore() >= 70) good++;
            else if (t.getScore() >= 50) fair++;
            else if (t.getScore() > 0) poor++;
            else newCount++;
        }

        List<BatterySwapTrustEntity> sortedDesc = all.stream()
                .sorted(Comparator.comparingInt(BatterySwapTrustEntity::getScore).reversed())
                .collect(Collectors.toList());

        List<BatterySwapTrustEntity> top5 = sortedDesc.stream().limit(5).collect(Collectors.toList());
        List<BatterySwapTrustEntity> bottom5 = sortedDesc.stream()
                .sorted(Comparator.comparingInt(BatterySwapTrustEntity::getScore))
                .limit(5)
                .collect(Collectors.toList());

        List<Map<String, Object>> topStationSummaries = top5.stream()
                .map(this::buildStationSummary)
                .collect(Collectors.toList());

        List<Map<String, Object>> bottomStationSummaries = bottom5.stream()
                .map(this::buildStationSummary)
                .collect(Collectors.toList());

        summary.put("totalStations", all.size());
        summary.put("excellentCount", excellent);
        summary.put("goodCount", good);
        summary.put("fairCount", fair);
        summary.put("poorCount", poor);
        summary.put("newCount", newCount);
        summary.put("highCount", excellent + good);
        summary.put("mediumCount", fair);
        summary.put("lowCount", poor + newCount);
        summary.put("averageScore", Math.round(avg * 10.0) / 10.0);
        summary.put("topStations", topStationSummaries);
        summary.put("bottomStations", bottomStationSummaries);

        return ResponseEntity.ok(summary);
    }

    @Operation(
            summary = "Recalculate trust score",
            description = "ADMIN only. Triggers a full recalculation of the trust score for the station."
    )
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/{stationId}/recalculate")
    public ResponseEntity<BatterySwapTrustScoreDTO> recalculateTrust(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {

        log.info("Recalculating trust for station: {}", stationId);

        BatterySwapTrustScoreDTO result = trustScoringService.recalculateAsDTO(stationId);
        return ResponseEntity.ok(result);
    }

    @Operation(
            summary = "Get trust score history",
            description = "ADMIN only. Returns the history of verification reviews for this station."
    )
    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping("/{stationId}/history")
    public ResponseEntity<List<VerificationReviewEntity>> getTrustHistory(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {

        log.info("Getting trust history for station: {}", stationId);

        List<VerificationReviewEntity> history = reviewRepository.findAllReviewsForStation(stationId);
        return ResponseEntity.ok(history);
    }

    private Map<String, Object> buildStationSummary(BatterySwapTrustEntity t) {
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("stationId", t.getStationId().toString());
        summary.put("score", t.getScore());
        summary.put("level", t.getTrustLevel());

        stationVersionRepository.findByStationIdAndWorkflowStatus(t.getStationId(), WorkflowStatus.PUBLISHED)
                .ifPresent(sv -> summary.put("stationName", sv.getName()));

        return summary;
    }
}
