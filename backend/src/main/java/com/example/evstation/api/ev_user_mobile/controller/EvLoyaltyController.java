package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.loyalty.api.dto.*;
import com.example.evstation.loyalty.application.*;
import com.example.evstation.loyalty.domain.EligibilityType;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/ev/loyalty")
@RequiredArgsConstructor
@Tag(name = "EV Loyalty", description = "EV User Loyalty Point System API")
public class EvLoyaltyController {

    private final LoyaltyPointService loyaltyPointService;
    private final StationRatingService stationRatingService;
    private final RatingEligibilityService ratingEligibilityService;
    private final BadgeService badgeService;
    private final ReferralService referralService;
    private final StationVersionJpaRepository stationVersionRepository;

    @Operation(summary = "Get current user's loyalty profile")
    @GetMapping("/me")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<LoyaltyUserProfileDTO> getMyProfile(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        var profileOpt = loyaltyPointService.getProfile(userId);
        if (profileOpt.isEmpty()) {
            return ResponseEntity.ok(LoyaltyUserProfileDTO.builder()
                    .userId(userId.toString())
                    .currentPoints(0)
                    .lifetimePoints(0)
                    .totalRatings(0)
                    .totalBookings(0)
                    .totalSwaps(0)
                    .totalContributions(0)
                    .level(1)
                    .levelName("Bronze")
                    .badges(List.of())
                    .pointsToNextLevel(100)
                    .pointsNeededForNextLevel(100)
                    .build());
        }
        var profile = profileOpt.get();
        String levelName = loyaltyPointService.getLevelName(profile.getLevel());
        List<UserBadgeDTO> badges = badgeService.getBadgesForUser(userId);
        return ResponseEntity.ok(LoyaltyUserProfileDTO.fromEntity(profile, badges, levelName));
    }

    @Operation(summary = "Get point history")
    @GetMapping("/points/history")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<Page<PointTransactionDTO>> getPointHistory(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        Page<PointTransactionDTO> history = loyaltyPointService.getHistory(userId, PageRequest.of(page, size))
                .map(PointTransactionDTO::fromEntity);
        return ResponseEntity.ok(history);
    }

    @Operation(summary = "Get eligible stations to rate")
    @GetMapping("/ratings/eligible")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<List<EligibleStationForRatingDTO>> getEligibleStations(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        var eligibilities = ratingEligibilityService.getUnratedEligibleStations(userId);
        List<EligibleStationForRatingDTO> result = eligibilities.stream().map(e -> {
            String name = stationVersionRepository.findPublishedByStationId(e.getStationId())
                    .map(StationVersionEntity::getName).orElse("Unknown Station");
            return EligibleStationForRatingDTO.fromEntity(e, name, "");
        }).toList();
        return ResponseEntity.ok(result);
    }

    @Operation(summary = "Get my ratings")
    @GetMapping("/ratings")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<List<StationRatingDTO>> getMyRatings(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        List<StationRatingDTO> ratings = stationRatingService.getMyRatings(userId).stream()
                .map(r -> {
                    String name = stationVersionRepository.findPublishedByStationId(r.getStationId())
                            .map(StationVersionEntity::getName).orElse("Unknown Station");
                    return StationRatingDTO.fromEntity(r, name);
                })
                .toList();
        return ResponseEntity.ok(ratings);
    }

    @Operation(summary = "Submit a rating")
    @PostMapping("/ratings")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<StationRatingDTO> submitRating(
            @Valid @RequestBody SubmitRatingRequestDTO request,
            Authentication authentication) {
        UUID userId = extractUserId(authentication);
        UUID stationId = UUID.fromString(request.getStationId());
        UUID eligibilityId = request.getEligibilityId() != null ? UUID.fromString(request.getEligibilityId()) : null;
        UUID sourceId = eligibilityId != null ? null : UUID.randomUUID();
        EligibilityType type = EligibilityType.BOOKING_USAGE;

        var entity = stationRatingService.submitRating(
                userId, stationId, eligibilityId,
                request.getRating(), request.getComment(),
                sourceId, type, java.time.Instant.now());

        String name = stationVersionRepository.findPublishedByStationId(stationId)
                .map(StationVersionEntity::getName).orElse("Unknown Station");
        return ResponseEntity.status(HttpStatus.CREATED).body(StationRatingDTO.fromEntity(entity, name));
    }

    @Operation(summary = "Mark a rating as helpful")
    @PostMapping("/ratings/{id}/helpful")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<Void> markHelpful(@PathVariable UUID id, Authentication authentication) {
        UUID userId = extractUserId(authentication);
        stationRatingService.markHelpful(id, userId);
        return ResponseEntity.ok().build();
    }

    @Operation(summary = "Get my badges")
    @GetMapping("/badges")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<List<UserBadgeDTO>> getMyBadges(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        return ResponseEntity.ok(badgeService.getBadgesForUser(userId));
    }

    @Operation(summary = "Get all badges with progress")
    @GetMapping("/badges/available")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<List<BadgeWithProgressDTO>> getAvailableBadges(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        return ResponseEntity.ok(badgeService.getAllBadgesWithProgress(userId));
    }

    @Operation(summary = "Generate referral code")
    @PostMapping("/referral/generate")
    @PreAuthorize("hasRole('EV_USER')")
    public ResponseEntity<ReferralCodeDTO> generateReferralCode(Authentication authentication) {
        UUID userId = extractUserId(authentication);
        String code = referralService.generateReferralCode(userId);
        String referralLink = "voltgo://register?ref=" + code;
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ReferralCodeDTO.builder().code(code).referralLink(referralLink).build());
    }

    @Operation(summary = "Get station ratings (public)")
    @GetMapping("/public/stations/{stationId}/ratings")
    @PreAuthorize("permitAll()")
    public ResponseEntity<Page<StationRatingDTO>> getStationRatings(
            @PathVariable UUID stationId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        Page<StationRatingDTO> ratings = stationRatingService.getRatingsForStation(stationId, PageRequest.of(page, size))
                .map(r -> {
                    String name = stationVersionRepository.findPublishedByStationId(r.getStationId())
                            .map(StationVersionEntity::getName).orElse("Unknown Station");
                    return StationRatingDTO.fromEntity(r, name);
                });
        return ResponseEntity.ok(ratings);
    }

    @Operation(summary = "Get station rating summary (public)")
    @GetMapping("/public/stations/{stationId}/summary")
    @PreAuthorize("permitAll()")
    public ResponseEntity<StationRatingSummaryDTO> getStationSummary(@PathVariable UUID stationId) {
        var summary = stationRatingService.getRatingSummary(stationId);
        return ResponseEntity.ok(StationRatingSummaryDTO.builder()
                .stationId(stationId.toString())
                .averageRating(summary.averageRating())
                .totalRatings(summary.totalRatings())
                .r1(summary.r1()).r2(summary.r2()).r3(summary.r3()).r4(summary.r4()).r5(summary.r5())
                .build());
    }

    private UUID extractUserId(Authentication authentication) {
        Object principal = authentication.getPrincipal();
        if (principal instanceof UUID) return (UUID) principal;
        return UUID.fromString(principal.toString());
    }
}
