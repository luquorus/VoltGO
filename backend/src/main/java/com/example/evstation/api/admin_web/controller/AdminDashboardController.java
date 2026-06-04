package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.admin_web.dto.*;
import com.example.evstation.common.web.PaginationRequest;
import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.station.domain.ServiceType;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.booking.infrastructure.jpa.BookingJpaRepository;
import com.example.evstation.booking.domain.BookingStatus;
import com.example.evstation.station.infrastructure.jpa.*;
import com.example.evstation.collaborator.infrastructure.jpa.ContractJpaRepository;
import com.example.evstation.collaborator.domain.ContractStatus;
import com.example.evstation.trust.infrastructure.jpa.StationTrustJpaRepository;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskJpaRepository;
import com.example.evstation.verification.domain.VerificationTaskStatus;
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
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Tag(name = "Admin Dashboard", description = "Admin API for dashboard analytics")
@RestController
@RequestMapping("/api/admin/dashboard")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class AdminDashboardController {

    private final StationJpaRepository stationJpaRepository;
    private final ChangeRequestJpaRepository changeRequestJpaRepository;
    private final ReportIssueJpaRepository reportIssueJpaRepository;
    private final VerificationTaskJpaRepository verificationTaskJpaRepository;
    private final ContractJpaRepository contractJpaRepository;
    private final BookingJpaRepository bookingJpaRepository;
    private final StationTrustJpaRepository stationTrustJpaRepository;
    private final StationVersionJpaRepository stationVersionJpaRepository;

    @Operation(summary = "Get dashboard statistics", description = "Get overview statistics for admin dashboard")
    @GetMapping("/stats")
    public ResponseEntity<DashboardStatsDTO> getDashboardStats() {
        log.info("Admin fetching dashboard stats");

        long stationCount = stationJpaRepository.count();
        long pendingCRs = changeRequestJpaRepository.findByStatusOrderByCreatedAtDesc(
                com.example.evstation.station.domain.ChangeRequestStatus.PENDING).size();
        long openIssues = reportIssueJpaRepository.findByStatusOrderByCreatedAtDesc(
                com.example.evstation.station.domain.IssueStatus.OPEN).size();

        Instant now = Instant.now();
        long overdueTasks = verificationTaskJpaRepository.findByStatusOrderByCreatedAtDesc(VerificationTaskStatus.ASSIGNED)
                .stream()
                .filter(t -> t.getSlaDueAt() != null && t.getSlaDueAt().isBefore(now))
                .count();

        long activeCollaborators = contractJpaRepository.findByStatusOrderByCreatedAtDesc(ContractStatus.ACTIVE).size();

        DashboardStatsDTO stats = DashboardStatsDTO.builder()
                .stationCount(stationCount)
                .pendingCRs(pendingCRs)
                .openIssues(openIssues)
                .overdueTasks(overdueTasks)
                .activeCollaborators(activeCollaborators)
                .build();

        return ResponseEntity.ok(stats);
    }

    @Operation(summary = "Get trend data", description = "Get daily trends for bookings, new stations, and new users")
    @GetMapping("/trends")
    public ResponseEntity<Map<String, List<TrendDataDTO>>> getTrends(
            @Parameter(description = "Number of days to look back")
            @RequestParam(defaultValue = "30") int days) {

        log.info("Admin fetching trend data for {} days", days);

        Instant since = Instant.now().minus(days, ChronoUnit.DAYS);
        ZoneId zoneId = ZoneId.systemDefault();

        List<TrendDataDTO> dailyBookings = getDailyBookingTrends(since, zoneId);
        List<TrendDataDTO> newStations = getDailyStationTrends(since, zoneId);
        List<TrendDataDTO> newUsers = getDailyUserTrends(since, zoneId);

        Map<String, List<TrendDataDTO>> trends = new HashMap<>();
        trends.put("dailyBookings", dailyBookings);
        trends.put("newStations", newStations);
        trends.put("newUsers", newUsers);

        return ResponseEntity.ok(trends);
    }

    private List<TrendDataDTO> getDailyBookingTrends(Instant since, ZoneId zoneId) {
        List<BookingStatus> activeStatuses = List.of(BookingStatus.HOLD, BookingStatus.CONFIRMED);
        return bookingJpaRepository.findAll().stream()
                .filter(b -> b.getCreatedAt().isAfter(since))
                .collect(Collectors.groupingBy(b -> LocalDate.ofInstant(b.getCreatedAt(), zoneId)))
                .entrySet().stream()
                .map(e -> TrendDataDTO.builder()
                        .date(e.getKey())
                        .count(e.getValue().size())
                        .build())
                .sorted(Comparator.comparing(TrendDataDTO::getDate))
                .collect(Collectors.toList());
    }

    private List<TrendDataDTO> getDailyStationTrends(Instant since, ZoneId zoneId) {
        return stationJpaRepository.findAll().stream()
                .filter(s -> s.getCreatedAt().isAfter(since))
                .collect(Collectors.groupingBy(s -> LocalDate.ofInstant(s.getCreatedAt(), zoneId)))
                .entrySet().stream()
                .map(e -> TrendDataDTO.builder()
                        .date(e.getKey())
                        .count(e.getValue().size())
                        .build())
                .sorted(Comparator.comparing(TrendDataDTO::getDate))
                .collect(Collectors.toList());
    }

    private List<TrendDataDTO> getDailyUserTrends(Instant since, ZoneId zoneId) {
        return stationJpaRepository.findAll().stream()
                .filter(s -> s.getProviderId() != null && s.getCreatedAt().isAfter(since))
                .collect(Collectors.groupingBy(s -> {
                    LocalDate date = LocalDate.ofInstant(s.getCreatedAt(), zoneId);
                    return date;
                }))
                .entrySet().stream()
                .map(e -> TrendDataDTO.builder()
                        .date(e.getKey())
                        .count(e.getValue().stream().map(s -> s.getProviderId()).distinct().count())
                        .build())
                .sorted(Comparator.comparing(TrendDataDTO::getDate))
                .collect(Collectors.toList());
    }

    @Operation(summary = "Get booking statistics", description = "Get booking statistics including completion rate and revenue")
    @GetMapping("/booking-stats")
    public ResponseEntity<BookingStatsDTO> getBookingStats() {
        log.info("Admin fetching booking stats");

        List<com.example.evstation.booking.infrastructure.jpa.BookingEntity> allBookings = bookingJpaRepository.findAll();

        long totalBookings = allBookings.size();
        long completedBookings = allBookings.stream()
                .filter(b -> b.getStatus() == BookingStatus.CONFIRMED)
                .count();
        long cancelledBookings = allBookings.stream()
                .filter(b -> b.getStatus() == BookingStatus.CANCELLED)
                .count();

        double completionRate = totalBookings > 0 ? (double) completedBookings / totalBookings * 100 : 0;
        double cancellationRate = totalBookings > 0 ? (double) cancelledBookings / totalBookings * 100 : 0;

        long revenue = completedBookings * 150000L;

        double avgDurationMinutes = allBookings.stream()
                .filter(b -> b.getStatus() == BookingStatus.CONFIRMED && b.getStartTime() != null && b.getEndTime() != null)
                .mapToLong(b -> ChronoUnit.MINUTES.between(b.getStartTime(), b.getEndTime()))
                .average()
                .orElse(0);

        BookingStatsDTO stats = BookingStatsDTO.builder()
                .totalBookings(totalBookings)
                .completionRate(Math.round(completionRate * 100.0) / 100.0)
                .cancellationRate(Math.round(cancellationRate * 100.0) / 100.0)
                .revenue(revenue)
                .avgSessionDurationMinutes(Math.round(avgDurationMinutes * 100.0) / 100.0)
                .build();

        return ResponseEntity.ok(stats);
    }

    @Operation(summary = "Get issue statistics", description = "Get issue statistics by category and resolution time")
    @GetMapping("/issue-stats")
    public ResponseEntity<IssueStatsDTO> getIssueStats() {
        log.info("Admin fetching issue stats");

        List<com.example.evstation.station.infrastructure.jpa.ReportIssueEntity> allIssues = reportIssueJpaRepository.findAll();

        long openCount = allIssues.stream()
                .filter(i -> i.getStatus() == com.example.evstation.station.domain.IssueStatus.OPEN)
                .count();

        List<IssueStatsDTO.IssueByCategory> issuesByCategory = allIssues.stream()
                .collect(Collectors.groupingBy(com.example.evstation.station.infrastructure.jpa.ReportIssueEntity::getCategory))
                .entrySet().stream()
                .map(e -> IssueStatsDTO.IssueByCategory.builder()
                        .category(e.getKey())
                        .count(e.getValue().size())
                        .build())
                .collect(Collectors.toList());

        double avgResolutionHours = allIssues.stream()
                .filter(i -> i.getStatus() == com.example.evstation.station.domain.IssueStatus.RESOLVED
                        && i.getCreatedAt() != null && i.getDecidedAt() != null)
                .mapToLong(i -> ChronoUnit.HOURS.between(i.getCreatedAt(), i.getDecidedAt()))
                .average()
                .orElse(0);

        IssueStatsDTO stats = IssueStatsDTO.builder()
                .openCount(openCount)
                .avgResolutionTimeHours(Math.round(avgResolutionHours * 100.0) / 100.0)
                .issuesByCategory(issuesByCategory)
                .build();

        return ResponseEntity.ok(stats);
    }

    @Operation(summary = "Get trust overview", description = "Get paginated list of stations with trust scores")
    @GetMapping("/trust-overview")
    public ResponseEntity<PaginationResponse<TrustOverviewDTO>> getTrustOverview(
            PaginationRequest pagination,
            @Parameter(description = "Sort by: score or name")
            @RequestParam(defaultValue = "score") String sortBy,
            @Parameter(description = "Sort direction: asc or desc")
            @RequestParam(defaultValue = "desc") String sortDir) {

        log.info("Admin fetching trust overview: page={}, size={}, sortBy={}, sortDir={}",
                pagination.getPage(), pagination.getSize(), sortBy, sortDir);

        Sort.Direction direction = sortDir.equalsIgnoreCase("asc") ? Sort.Direction.ASC : Sort.Direction.DESC;
        String sortField = sortBy.equalsIgnoreCase("name") ? "name" : "score";
        Pageable pageable = PageRequest.of(pagination.getPage(), pagination.getSize(), direction, sortField);

        Page<TrustOverviewDTO> page = getTrustOverviewPage(pageable);

        return ResponseEntity.ok(PaginationResponse.fromPage(page));
    }

    private Page<TrustOverviewDTO> getTrustOverviewPage(Pageable pageable) {
        var trustEntities = stationTrustJpaRepository.findAll();
        List<TrustOverviewDTO> dtos = new ArrayList<>();

        for (var trust : trustEntities) {
            var stationVersions = stationVersionJpaRepository.findPublishedByStationIds(List.of(trust.getStationId()));
            if (!stationVersions.isEmpty()) {
                var version = stationVersions.get(0);
                dtos.add(TrustOverviewDTO.builder()
                        .stationId(trust.getStationId())
                        .name(version.getName())
                        .address(version.getAddress())
                        .trustScore(trust.getScore())
                        .serviceType(ServiceType.CHARGING)
                        .build());
            }
        }

        int start = (int) pageable.getOffset();
        int end = Math.min((start + pageable.getPageSize()), dtos.size());

        List<TrustOverviewDTO> pageContent = start < dtos.size() ? dtos.subList(start, end) : List.of();

        return new org.springframework.data.domain.PageImpl<>(pageContent, pageable, dtos.size());
    }
}
