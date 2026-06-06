package com.example.evstation.api.admin_web.controller;

import com.example.evstation.loyalty.api.dto.*;
import com.example.evstation.loyalty.application.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/admin/loyalty")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
@Tag(name = "Admin Loyalty", description = "Admin Loyalty Point Management API")
public class AdminLoyaltyController {

    private final LoyaltyPointService loyaltyPointService;
    private final StationRatingService stationRatingService;
    private final BadgeService badgeService;

    @Operation(summary = "Get loyalty dashboard stats")
    @GetMapping("/dashboard")
    public ResponseEntity<LoyaltyDashboardDTO> getDashboard() {
        return ResponseEntity.ok(LoyaltyDashboardDTO.builder()
                .totalPointsIssued(0)
                .activeUsers(0)
                .totalRatings(0)
                .build());
    }

    @Operation(summary = "List users with loyalty profiles")
    @GetMapping("/users")
    public ResponseEntity<Page<LoyaltyUserProfileDTO>> listUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(Page.empty());
    }

    @Operation(summary = "Get user loyalty detail")
    @GetMapping("/users/{userId}")
    public ResponseEntity<LoyaltyUserProfileDTO> getUserDetail(@PathVariable UUID userId) {
        var profileOpt = loyaltyPointService.getProfile(userId);
        if (profileOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        var profile = profileOpt.get();
        String levelName = loyaltyPointService.getLevelName(profile.getLevel());
        return ResponseEntity.ok(LoyaltyUserProfileDTO.fromEntity(profile,
                badgeService.getBadgesForUser(userId), levelName));
    }

    @Operation(summary = "Get user point history")
    @GetMapping("/users/{userId}/history")
    public ResponseEntity<Page<PointTransactionDTO>> getUserHistory(
            @PathVariable UUID userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<PointTransactionDTO> history = loyaltyPointService.getHistory(userId, PageRequest.of(page, size))
                .map(PointTransactionDTO::fromEntity);
        return ResponseEntity.ok(history);
    }

    @Operation(summary = "Manual point adjustment")
    @PostMapping("/users/{userId}/adjust")
    public ResponseEntity<Void> adjustPoints(
            @PathVariable UUID userId,
            @Valid @RequestBody AdjustPointsRequestDTO request) {
        loyaltyPointService.adjustPoints(userId, request.getDelta(), request.getReason());
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "List all ratings")
    @GetMapping("/ratings")
    public ResponseEntity<Page<StationRatingDTO>> listRatings(
            @RequestParam(required = false) String stationId,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(Page.empty());
    }

    @Operation(summary = "Hide a rating")
    @PutMapping("/ratings/{id}/hide")
    public ResponseEntity<Void> hideRating(@PathVariable UUID id) {
        stationRatingService.hideRating(id);
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "List all badges")
    @GetMapping("/badges")
    public ResponseEntity<?> listBadges() {
        return ResponseEntity.ok(badgeService.getAllBadgesWithProgress(null));
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) return (UUID) principal;
        return UUID.fromString(principal.toString());
    }
}
