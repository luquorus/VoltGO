package com.example.evstation.batteryswapchange.web;

import com.example.evstation.batteryswap.application.BatterySwapTrustScoreDTO;
import com.example.evstation.batteryswap.application.BatterySwapTrustScoringService;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapTrustJpaRepository;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewJpaRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Tag(name = "Battery Swap Trust", description = "API for managing battery swap station trust scores")
@RestController
@RequestMapping("/api/v1/battery-swap/trust")
@RequiredArgsConstructor
public class BatterySwapTrustController {

    private final BatterySwapTrustScoringService trustScoringService;
    private final BatterySwapTrustJpaRepository trustRepository;
    private final VerificationReviewJpaRepository reviewRepository;

    @Operation(
            summary = "Get trust score for a battery swap station",
            description = "Returns the trust score DTO for the specified station ID."
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
            description = "Returns the trust score breakdown by dimension (accuracy, reliability, safety, etc.)"
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
            description = "Returns the trust level (HIGH if score >= 70, MEDIUM if 30-69, LOW if < 30)"
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
            summary = "Recalculate trust score",
            description = "Triggers a full recalculation of the trust score for the station."
    )
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
            description = "Returns the history of verification reviews for this station."
    )
    @GetMapping("/{stationId}/history")
    public ResponseEntity<List<VerificationReviewEntity>> getTrustHistory(
            @Parameter(description = "Station ID", required = true)
            @PathVariable UUID stationId) {

        log.info("Getting trust history for station: {}", stationId);

        List<VerificationReviewEntity> history = reviewRepository.findAllReviewsForStation(stationId);
        return ResponseEntity.ok(history);
    }
}
