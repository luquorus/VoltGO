package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.ev_user_mobile.dto.RecommendationRequestDTO;
import com.example.evstation.api.ev_user_mobile.dto.SmartTimeSuggestionRequestDTO;
import com.example.evstation.station.application.EvUserAiService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@Tag(name = "EV User AI", description = "AI endpoints for EV User suggestions")
@RestController
@RequestMapping("/api/ev/ai")
@RequiredArgsConstructor
public class EvUserAiController {

    private final EvUserAiService evUserAiService;

    @Operation(summary = "Get personalized station recommendations")
    @PostMapping("/personalized-recommendations")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<Map<String, Object>> getPersonalizedRecommendations(
            @Valid @RequestBody RecommendationRequestDTO request,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        return ResponseEntity.ok(evUserAiService.getPersonalizedRecommendations(userId, request));
    }

    @Operation(summary = "Suggest smart charging time slots")
    @PostMapping("/smart-time-suggestions")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<Map<String, Object>> getSmartTimeSuggestions(
            @Valid @RequestBody SmartTimeSuggestionRequestDTO request,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        double speed = request.getAverageSpeedKmph() != null ? request.getAverageSpeedKmph() : 30.0;
        return ResponseEntity.ok(evUserAiService.getSmartTimeSuggestions(
                userId,
                request.getStationId(),
                request.getDistanceKm(),
                request.getBatteryPercent(),
                request.getTargetPercent(),
                request.getBatteryCapacityKwh(),
                speed
        ));
    }
}
