package com.example.evstation.api.admin_web.controller;

import com.example.evstation.loyalty.api.dto.*;
import com.example.evstation.loyalty.application.*;
import com.example.evstation.loyalty.domain.RedemptionStatus;
import com.example.evstation.loyalty.domain.RatingStatus;
import com.example.evstation.loyalty.domain.VoucherStatus;
import com.example.evstation.loyalty.domain.VoucherType;
import com.example.evstation.loyalty.infrastructure.jpa.*;
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

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
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
    private final VoucherService voucherService;
    private final LoyaltyUserProfileJpaRepository profileRepo;
    private final StationRatingJpaRepository ratingRepo;
    private final StationVersionJpaRepository stationVersionRepo;

    @Operation(summary = "Get loyalty dashboard stats")
    @GetMapping("/dashboard")
    public ResponseEntity<LoyaltyDashboardDTO> getDashboard() {
        Instant thirtyDaysAgo = Instant.now().minus(30, ChronoUnit.DAYS);

        int totalPoints = profileRepo.sumLifetimePoints();
        long activeUsers = profileRepo.countActiveUsersSince(thirtyDaysAgo);
        long totalRatings = ratingRepo.countByStatus(RatingStatus.ACTIVE);

        return ResponseEntity.ok(LoyaltyDashboardDTO.builder()
                .totalPointsIssued(totalPoints)
                .activeUsers((int) activeUsers)
                .totalRatings((int) totalRatings)
                .build());
    }

    @Operation(summary = "List users with loyalty profiles")
    @GetMapping("/users")
    public ResponseEntity<Page<LoyaltyUserProfileDTO>> listUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<LoyaltyUserProfileEntity> profiles = profileRepo.findAllByOrderByCurrentPointsDesc(
                PageRequest.of(page, size));

        List<LoyaltyUserProfileDTO> dtos = profiles.getContent().stream()
                .map(entity -> {
                    String levelName = loyaltyPointService.getLevelName(entity.getLevel());
                    List<UserBadgeDTO> badges = badgeService.getBadgesForUser(entity.getUserId());
                    return LoyaltyUserProfileDTO.fromEntity(entity, badges, levelName);
                })
                .toList();

        Page<LoyaltyUserProfileDTO> result = new org.springframework.data.domain.PageImpl<>(
                dtos, PageRequest.of(page, size), profiles.getTotalElements());
        return ResponseEntity.ok(result);
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
        Page<StationRatingEntity> ratings;
        if (stationId != null && !stationId.isEmpty()) {
            UUID sid = UUID.fromString(stationId);
            ratings = ratingRepo.findByStationIdOrderByCreatedAtDesc(sid, PageRequest.of(page, size));
        } else if (status != null && !status.isEmpty()) {
            RatingStatus rs = RatingStatus.valueOf(status);
            ratings = ratingRepo.findByStatusOrderByCreatedAtDesc(rs, PageRequest.of(page, size));
        } else {
            ratings = ratingRepo.findAllByOrderByCreatedAtDesc(PageRequest.of(page, size));
        }

        List<UUID> stationIds = ratings.getContent().stream()
                .map(StationRatingEntity::getStationId)
                .distinct()
                .toList();
        Map<UUID, String> stationNames = stationVersionRepo.findPublishedByStationIds(stationIds).stream()
                .collect(java.util.stream.Collectors.toMap(
                        com.example.evstation.station.infrastructure.jpa.StationVersionEntity::getStationId,
                        com.example.evstation.station.infrastructure.jpa.StationVersionEntity::getName,
                        (a, b) -> a));

        List<StationRatingDTO> dtos = ratings.getContent().stream()
                .map(e -> StationRatingDTO.fromEntity(e, stationNames.get(e.getStationId())))
                .toList();

        Page<StationRatingDTO> result = new org.springframework.data.domain.PageImpl<>(
                dtos, PageRequest.of(page, size), ratings.getTotalElements());
        return ResponseEntity.ok(result);
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

    // === VOUCHER ADMIN ENDPOINTS ===
    @Operation(summary = "List all voucher definitions")
    @GetMapping("/vouchers")
    public ResponseEntity<List<VoucherDefinitionDTO>> listVouchers() {
        var vouchers = voucherService.getAllDefinitions().stream()
                .map(v -> VoucherDefinitionDTO.fromEntity(v, voucherService.getRedemptionCount(v.getId())))
                .toList();
        return ResponseEntity.ok(vouchers);
    }

    @Operation(summary = "Get voucher definition by id")
    @GetMapping("/vouchers/{id}")
    public ResponseEntity<VoucherDefinitionDTO> getVoucher(@PathVariable UUID id) {
        var def = voucherService.getDefinitionById(id);
        long count = voucherService.getRedemptionCount(id);
        return ResponseEntity.ok(VoucherDefinitionDTO.fromEntity(def, count));
    }

    @Operation(summary = "Create voucher definition")
    @PostMapping("/vouchers")
    public ResponseEntity<VoucherDefinitionDTO> createVoucher(
            @Valid @RequestBody CreateVoucherDefinitionRequestDTO request) {
        VoucherDefinitionEntity entity = VoucherDefinitionEntity.builder()
                .code(request.getCode())
                .name(request.getName())
                .description(request.getDescription())
                .voucherType(VoucherType.valueOf(request.getVoucherType()))
                .pointCost(request.getPointCost())
                .discountPercent(request.getDiscountPercent())
                .maxValueVnd(request.getMaxValueVnd())
                .serviceType(request.getServiceType())
                .startDate(request.getStartDate())
                .endDate(request.getEndDate())
                .validityDays(request.getValidityDays() != null ? request.getValidityDays() : 30)
                .build();
        entity = voucherService.createDefinition(entity);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(VoucherDefinitionDTO.fromEntity(entity, 0L));
    }

    @Operation(summary = "Update voucher definition")
    @PutMapping("/vouchers/{id}")
    public ResponseEntity<VoucherDefinitionDTO> updateVoucher(
            @PathVariable UUID id,
            @Valid @RequestBody UpdateVoucherDefinitionRequestDTO request) {
        VoucherDefinitionEntity updates = VoucherDefinitionEntity.builder()
                .name(request.getName())
                .description(request.getDescription())
                .voucherType(request.getVoucherType() != null ? VoucherType.valueOf(request.getVoucherType()) : null)
                .pointCost(request.getPointCost())
                .discountPercent(request.getDiscountPercent())
                .maxValueVnd(request.getMaxValueVnd())
                .serviceType(request.getServiceType())
                .startDate(request.getStartDate())
                .endDate(request.getEndDate())
                .validityDays(request.getValidityDays())
                .build();
        var updated = voucherService.updateDefinition(id, updates);
        long count = voucherService.getRedemptionCount(id);
        return ResponseEntity.ok(VoucherDefinitionDTO.fromEntity(updated, count));
    }

    @Operation(summary = "Update voucher status")
    @PatchMapping("/vouchers/{id}/status")
    public ResponseEntity<VoucherDefinitionDTO> updateVoucherStatus(
            @PathVariable UUID id,
            @RequestBody Map<String, String> body) {
        VoucherStatus status = VoucherStatus.valueOf(body.get("status"));
        var updated = voucherService.updateDefinitionStatus(id, status);
        long count = voucherService.getRedemptionCount(id);
        return ResponseEntity.ok(VoucherDefinitionDTO.fromEntity(updated, count));
    }

    @Operation(summary = "Get voucher redemption stats")
    @GetMapping("/vouchers/{id}/stats")
    public ResponseEntity<Map<String, Object>> getVoucherStats(@PathVariable UUID id) {
        long count = voucherService.getRedemptionCount(id);
        return ResponseEntity.ok(Map.of(
                "definitionId", id.toString(),
                "totalRedemptions", count
        ));
    }

    @Operation(summary = "List all redemptions")
    @GetMapping("/redemptions")
    public ResponseEntity<Page<VoucherRedemptionDTO>> listRedemptions(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        RedemptionStatus rs = status != null ? RedemptionStatus.valueOf(status) : null;
        var redemptions = voucherService.getAllRedemptions(rs, PageRequest.of(page, size))
                .map(r -> {
                    try {
                        var def = voucherService.getDefinitionById(r.getVoucherDefinitionId());
                        long count = voucherService.getRedemptionCount(r.getVoucherDefinitionId());
                        return VoucherRedemptionDTO.fromEntity(r, def, count);
                    } catch (Exception e) {
                        return VoucherRedemptionDTO.fromEntity(r, null, 0L);
                    }
                });
        return ResponseEntity.ok(redemptions);
    }
}
