package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.admin_web.dto.CollaboratorPerformanceDTO;
import com.example.evstation.api.admin_web.dto.CollaboratorPerformanceDetailDTO;
import com.example.evstation.api.admin_web.dto.CollaboratorPerformancePageDTO;
import com.example.evstation.api.admin_web.dto.MonthlyBreakdownDTO;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskJpaRepository;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewJpaRepository;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationReviewEntity;
import com.example.evstation.verification.domain.VerificationResult;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Tag(name = "Admin Collaborators", description = "Admin API for collaborator performance analytics")
@RestController
@RequestMapping("/api/admin/collaborators")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminCollaboratorController {

    private final CollaboratorProfileJpaRepository collaboratorProfileRepository;
    private final VerificationTaskJpaRepository taskRepository;
    private final VerificationReviewJpaRepository reviewRepository;
    private final StationVersionJpaRepository stationVersionRepository;

    @Operation(summary = "Get collaborator performance list",
            description = "Get paginated list of collaborators with their performance metrics")
    @GetMapping("/performance")
    public ResponseEntity<CollaboratorPerformancePageDTO> getCollaboratorPerformance(
            @Parameter(description = "Page number")
            @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size")
            @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "Sort by: totalTasks, passRate, avgCompletionHours")
            @RequestParam(defaultValue = "totalTasks") String sortBy,
            @Parameter(description = "Sort direction: asc or desc")
            @RequestParam(defaultValue = "desc") String sortDir) {

        log.info("Admin fetching collaborator performance: page={}, size={}, sortBy={}, sortDir={}",
                page, size, sortBy, sortDir);

        Sort.Direction direction = sortDir.equalsIgnoreCase("asc") ? Sort.Direction.ASC : Sort.Direction.DESC;
        String sortField = switch (sortBy) {
            case "passRate" -> "passRate";
            case "avgCompletionHours" -> "avgCompletionHours";
            default -> "totalTasks";
        };

        Pageable pageable = PageRequest.of(page, size, direction, sortField);
        Page<CollaboratorPerformanceDTO> resultPage = getCollaboratorPerformancePage(pageable);

        return ResponseEntity.ok(CollaboratorPerformancePageDTO.builder()
                .content(resultPage.getContent())
                .page(resultPage.getNumber())
                .size(resultPage.getSize())
                .totalElements(resultPage.getTotalElements())
                .totalPages(resultPage.getTotalPages())
                .first(resultPage.isFirst())
                .last(resultPage.isLast())
                .build());
    }

    @Operation(summary = "Get collaborator performance detail",
            description = "Get detailed performance metrics for a specific collaborator including monthly breakdown")
    @GetMapping("/{collaboratorId}/performance")
    public ResponseEntity<CollaboratorPerformanceDetailDTO> getCollaboratorPerformanceDetail(
            @Parameter(description = "Collaborator ID", required = true)
            @PathVariable UUID collaboratorId) {

        log.info("Admin fetching collaborator performance detail: {}", collaboratorId);

        Optional<CollaboratorProfileEntity> profileOpt = collaboratorProfileRepository.findById(collaboratorId);
        if (profileOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        CollaboratorProfileEntity profile = profileOpt.get();
        CollaboratorPerformanceDetailDTO detail = buildCollaboratorPerformanceDetail(profile);

        return ResponseEntity.ok(detail);
    }

    private Page<CollaboratorPerformanceDTO> getCollaboratorPerformancePage(Pageable pageable) {
        List<CollaboratorProfileEntity> allProfiles = collaboratorProfileRepository.findAll();
        List<CollaboratorPerformanceDTO> performances = new ArrayList<>();

        for (CollaboratorProfileEntity profile : allProfiles) {
            performances.add(buildCollaboratorPerformance(profile));
        }

        // Sort in memory based on pageable
        Sort sort = pageable.getSort();
        Comparator<CollaboratorPerformanceDTO> comparator = getComparatorFromSort(sort);
        performances.sort(comparator);

        int start = (int) pageable.getOffset();
        int end = Math.min((start + pageable.getPageSize()), performances.size());

        List<CollaboratorPerformanceDTO> pageContent = start < performances.size()
                ? performances.subList(start, end)
                : List.of();

        return new org.springframework.data.domain.PageImpl<>(pageContent, pageable, performances.size());
    }

    private Comparator<CollaboratorPerformanceDTO> getComparatorFromSort(Sort sort) {
        Comparator<CollaboratorPerformanceDTO> comparator = (a, b) -> 0;

        for (Sort.Order order : sort) {
            String property = order.getProperty();
            int multiplier = order.getDirection() == Sort.Direction.ASC ? 1 : -1;

            comparator = comparator.thenComparing((a, b) -> {
                int result = switch (property) {
                    case "passRate" -> Double.compare(a.getPassRate(), b.getPassRate());
                    case "avgCompletionHours" -> Double.compare(a.getAvgCompletionTimeHours(), b.getAvgCompletionTimeHours());
                    default -> Long.compare(a.getTotalTasks(), b.getTotalTasks());
                };
                return result * multiplier;
            });
        }

        return comparator;
    }

    private CollaboratorPerformanceDTO buildCollaboratorPerformance(CollaboratorProfileEntity profile) {
        UUID userAccountId = profile.getUserAccountId();

        List<VerificationTaskEntity> allTasks = taskRepository.findByAssignedTo(userAccountId);
        List<VerificationReviewEntity> allReviews = getReviewsForCollaborator(userAccountId);

        long totalTasks = allTasks.size();
        long completedTasks = allReviews.size();
        long passedTasks = allReviews.stream()
                .filter(r -> r.getResult() == VerificationResult.PASS)
                .count();

        double passRate = completedTasks > 0 ? (double) passedTasks / completedTasks * 100 : 0;

        double avgCompletionHours = calculateAverageCompletionHours(allTasks, allReviews);

        double avgDistanceMeters = calculateAverageDistance(allTasks, allReviews, profile);

        double slaComplianceRate = calculateSlaComplianceRate(allTasks, allReviews);

        return CollaboratorPerformanceDTO.builder()
                .collaboratorId(profile.getId())
                .fullName(profile.getFullName())
                .totalTasks(totalTasks)
                .passRate(Math.round(passRate * 100.0) / 100.0)
                .avgCompletionTimeHours(Math.round(avgCompletionHours * 100.0) / 100.0)
                .avgDistanceMeters(Math.round(avgDistanceMeters * 100.0) / 100.0)
                .slaComplianceRate(Math.round(slaComplianceRate * 100.0) / 100.0)
                .build();
    }

    private CollaboratorPerformanceDetailDTO buildCollaboratorPerformanceDetail(CollaboratorProfileEntity profile) {
        CollaboratorPerformanceDTO perf = buildCollaboratorPerformance(profile);
        List<MonthlyBreakdownDTO> monthlyBreakdown = calculateMonthlyBreakdown(profile.getUserAccountId());

        return CollaboratorPerformanceDetailDTO.builder()
                .collaboratorId(perf.getCollaboratorId())
                .fullName(perf.getFullName())
                .totalTasks(perf.getTotalTasks())
                .passRate(perf.getPassRate())
                .avgCompletionTimeHours(perf.getAvgCompletionTimeHours())
                .avgDistanceMeters(perf.getAvgDistanceMeters())
                .slaComplianceRate(perf.getSlaComplianceRate())
                .monthlyBreakdown(monthlyBreakdown)
                .build();
    }

    private List<VerificationReviewEntity> getReviewsForCollaborator(UUID userAccountId) {
        List<VerificationTaskEntity> tasks = taskRepository.findByAssignedTo(userAccountId);
        List<VerificationReviewEntity> reviews = new ArrayList<>();

        for (VerificationTaskEntity task : tasks) {
            reviewRepository.findByTaskId(task.getId()).ifPresent(reviews::add);
        }

        return reviews;
    }

    private double calculateAverageCompletionHours(List<VerificationTaskEntity> tasks,
                                                   List<VerificationReviewEntity> reviews) {
        if (reviews.isEmpty()) {
            return 0;
        }

        Map<UUID, VerificationReviewEntity> reviewMap = reviews.stream()
                .collect(Collectors.toMap(VerificationReviewEntity::getTaskId, r -> r));

        double totalHours = 0;
        int count = 0;

        for (VerificationTaskEntity task : tasks) {
            VerificationReviewEntity review = reviewMap.get(task.getId());
            if (review != null && task.getCreatedAt() != null && review.getReviewedAt() != null) {
                long hours = ChronoUnit.HOURS.between(task.getCreatedAt(), review.getReviewedAt());
                totalHours += hours;
                count++;
            }
        }

        return count > 0 ? totalHours / count : 0;
    }

    private double calculateAverageDistance(List<VerificationTaskEntity> tasks,
                                                   List<VerificationReviewEntity> reviews,
                                                   CollaboratorProfileEntity profile) {
        if (reviews.isEmpty()) {
            return 0;
        }

        // Get collaborator's current location
        Double collabLat = profile.getLatitude();
        Double collabLng = profile.getLongitude();

        if (collabLat == null || collabLng == null) {
            return 0;
        }

        double totalDistance = 0;
        int count = 0;

        for (VerificationReviewEntity review : reviews) {
            Optional<VerificationTaskEntity> taskOpt = tasks.stream()
                    .filter(t -> t.getId().equals(review.getTaskId()))
                    .findFirst();

            if (taskOpt.isPresent()) {
                UUID stationId = taskOpt.get().getStationId();
                Optional<StationVersionEntity> stationVersion = stationVersionRepository
                        .findPublishedByStationId(stationId);

                if (stationVersion.isPresent() && stationVersion.get().getLocation() != null) {
                    double stationLat = stationVersion.get().getLocation().getY();
                    double stationLng = stationVersion.get().getLocation().getX();

                    double distance = calculateHaversineDistance(
                            collabLat, collabLng,
                            stationLat, stationLng
                    );
                    totalDistance += distance;
                    count++;
                }
            }
        }

        return count > 0 ? totalDistance / count : 0;
    }

    private double calculateHaversineDistance(double lat1, double lng1, double lat2, double lng2) {
        final double R = 6371000;

        double lat1Rad = Math.toRadians(lat1);
        double lat2Rad = Math.toRadians(lat2);
        double deltaLat = Math.toRadians(lat2 - lat1);
        double deltaLng = Math.toRadians(lng2 - lng1);

        double a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2)
                + Math.cos(lat1Rad) * Math.cos(lat2Rad)
                * Math.sin(deltaLng / 2) * Math.sin(deltaLng / 2);

        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return R * c;
    }

    private double calculateSlaComplianceRate(List<VerificationTaskEntity> tasks,
                                               List<VerificationReviewEntity> reviews) {
        if (reviews.isEmpty()) {
            return 100;
        }

        Map<UUID, VerificationReviewEntity> reviewMap = reviews.stream()
                .collect(Collectors.toMap(VerificationReviewEntity::getTaskId, r -> r));

        long compliantCount = 0;
        long reviewedCount = 0;

        for (VerificationTaskEntity task : tasks) {
            if (task.getSlaDueAt() != null) {
                VerificationReviewEntity review = reviewMap.get(task.getId());
                if (review != null && review.getReviewedAt() != null) {
                    reviewedCount++;
                    if (!review.getReviewedAt().isAfter(task.getSlaDueAt())) {
                        compliantCount++;
                    }
                }
            }
        }

        return reviewedCount > 0 ? (double) compliantCount / reviewedCount * 100 : 100;
    }

    private List<MonthlyBreakdownDTO> calculateMonthlyBreakdown(UUID userAccountId) {
        List<VerificationTaskEntity> tasks = taskRepository.findByAssignedTo(userAccountId);
        List<VerificationReviewEntity> reviews = getReviewsForCollaborator(userAccountId);

        Map<UUID, VerificationReviewEntity> reviewMap = reviews.stream()
                .collect(Collectors.toMap(VerificationReviewEntity::getTaskId, r -> r));

        ZoneId zoneId = ZoneId.systemDefault();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM");

        Map<String, List<VerificationReviewEntity>> byMonth = new TreeMap<>();

        for (VerificationTaskEntity task : tasks) {
            VerificationReviewEntity review = reviewMap.get(task.getId());
            if (review != null && review.getReviewedAt() != null) {
                String monthKey = LocalDate.ofInstant(review.getReviewedAt(), zoneId).format(formatter);
                byMonth.computeIfAbsent(monthKey, k -> new ArrayList<>()).add(review);
            }
        }

        List<MonthlyBreakdownDTO> breakdown = new ArrayList<>();

        for (Map.Entry<String, List<VerificationReviewEntity>> entry : byMonth.entrySet()) {
            String month = entry.getKey();
            List<VerificationReviewEntity> monthReviews = entry.getValue();

            long passedCount = monthReviews.stream()
                    .filter(r -> r.getResult() == VerificationResult.PASS)
                    .count();

            double passRate = monthReviews.size() > 0
                    ? (double) passedCount / monthReviews.size() * 100
                    : 0;

            breakdown.add(MonthlyBreakdownDTO.builder()
                    .month(month)
                    .tasksCompleted(monthReviews.size())
                    .passRate(Math.round(passRate * 100.0) / 100.0)
                    .build());
        }

        return breakdown;
    }
}
