package com.example.evstation.station.application;

import com.example.evstation.api.admin_web.dto.AdminIssueResponseDTO;
import com.example.evstation.api.ev_user_mobile.dto.CreateIssueDTO;
import com.example.evstation.api.ev_user_mobile.dto.IssueResponseDTO;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.IssueStatus;
import com.example.evstation.station.infrastructure.jpa.*;
import com.example.evstation.trust.application.TrustScoringService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ReportIssueService {
    
    private final ReportIssueJpaRepository reportIssueRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final TrustScoringService trustScoringService;

    // ========== EV User Operations ==========

    /**
     * Create a new issue report for a published station.
     */
    @Transactional
    public IssueResponseDTO createIssue(UUID stationId, CreateIssueDTO dto, UUID userId) {
        log.info("Creating issue: stationId={}, category={}, userId={}", stationId, dto.getCategory(), userId);
        
        // Verify station has a published version
        Optional<StationVersionEntity> publishedVersion = stationVersionRepository
                .findPublishedByStationId(stationId);
        
        if (publishedVersion.isEmpty()) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Cannot report issue on station without published version");
        }
        
        // Create issue
        ReportIssueEntity issue = ReportIssueEntity.builder()
                .stationId(stationId)
                .reporterId(userId)
                .category(dto.getCategory())
                .description(dto.getDescription())
                .status(IssueStatus.OPEN)
                .createdAt(Instant.now())
                .build();
        
        reportIssueRepository.save(issue);
        log.info("Issue created: id={}", issue.getId());
        
        // Write audit log
        writeAuditLog(userId, "EV_USER", "REPORT_ISSUE", "REPORT_ISSUE", issue.getId(),
                Map.of(
                        "stationId", stationId.toString(),
                        "stationName", publishedVersion.get().getName(),
                        "category", dto.getCategory().name()
                ));
        
        // Recalculate trust score after issue creation
        trustScoringService.recalculate(stationId);
        
        return buildUserDTO(issue, publishedVersion.get().getName());
    }

    /**
     * Get all issues reported by the current user.
     */
    @Transactional(readOnly = true)
    public List<IssueResponseDTO> getMyIssues(UUID userId) {
        log.info("Getting issues for user: {}", userId);
        
        List<ReportIssueEntity> issues = reportIssueRepository
                .findByReporterIdOrderByCreatedAtDesc(userId);
        
        // Load station names
        List<UUID> stationIds = issues.stream()
                .map(ReportIssueEntity::getStationId)
                .distinct()
                .toList();
        
        Map<UUID, String> stationNames = loadStationNames(stationIds);
        
        return issues.stream()
                .map(issue -> buildUserDTO(issue, stationNames.get(issue.getStationId())))
                .collect(Collectors.toList());
    }

    // ========== Admin Operations ==========

    /**
     * Get issues with optional status filter (for admin).
     */
    @Transactional(readOnly = true)
    public List<AdminIssueResponseDTO> getIssuesByStatus(IssueStatus status) {
        log.info("Admin getting issues: status={}", status);
        
        List<ReportIssueEntity> issues;
        if (status != null) {
            issues = reportIssueRepository.findByStatusOrderByCreatedAtDesc(status);
        } else {
            issues = reportIssueRepository.findAll();
        }
        
        // Load station names and reporter emails
        List<UUID> stationIds = issues.stream()
                .map(ReportIssueEntity::getStationId)
                .distinct()
                .toList();
        List<UUID> reporterIds = issues.stream()
                .map(ReportIssueEntity::getReporterId)
                .distinct()
                .toList();
        
        Map<UUID, String> stationNames = loadStationNames(stationIds);
        Map<UUID, String> reporterEmails = loadUserEmails(reporterIds);
        
        return issues.stream()
                .map(issue -> buildAdminDTO(issue, 
                        stationNames.get(issue.getStationId()),
                        reporterEmails.get(issue.getReporterId())))
                .collect(Collectors.toList());
    }

    /**
     * Get a specific issue by ID (for admin).
     */
    @Transactional(readOnly = true)
    public Optional<AdminIssueResponseDTO> getIssueById(UUID issueId) {
        return reportIssueRepository.findById(issueId)
                .map(issue -> {
                    String stationName = loadStationNames(List.of(issue.getStationId()))
                            .get(issue.getStationId());
                    String reporterEmail = loadUserEmails(List.of(issue.getReporterId()))
                            .get(issue.getReporterId());
                    return buildAdminDTO(issue, stationName, reporterEmail);
                });
    }

    /**
     * Acknowledge an issue (OPEN -> ACKNOWLEDGED).
     */
    @Transactional
    public AdminIssueResponseDTO acknowledgeIssue(UUID issueId, UUID adminId, String adminRole) {
        log.info("Admin acknowledging issue: id={}, adminId={}", issueId, adminId);
        
        ReportIssueEntity issue = reportIssueRepository.findById(issueId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Issue not found"));
        
        if (issue.getStatus() != IssueStatus.OPEN) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Only OPEN issues can be acknowledged. Current status: " + issue.getStatus());
        }
        
        issue.setStatus(IssueStatus.ACKNOWLEDGED);
        reportIssueRepository.save(issue);
        
        // Audit log
        writeAuditLog(adminId, adminRole, "ADMIN_ACK_ISSUE", "REPORT_ISSUE", issueId,
                Map.of("previousStatus", "OPEN", "newStatus", "ACKNOWLEDGED"));
        
        // Recalculate trust score (ACKNOWLEDGED still counts as unresolved)
        trustScoringService.recalculate(issue.getStationId());
        
        log.info("Issue acknowledged: id={}", issueId);
        return getIssueById(issueId).orElseThrow();
    }

    /**
     * Resolve an issue (OPEN/ACKNOWLEDGED -> RESOLVED).
     */
    @Transactional
    public AdminIssueResponseDTO resolveIssue(UUID issueId, String note, UUID adminId, String adminRole) {
        log.info("Admin resolving issue: id={}, adminId={}", issueId, adminId);
        
        ReportIssueEntity issue = reportIssueRepository.findById(issueId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Issue not found"));
        
        if (issue.getStatus() != IssueStatus.OPEN && issue.getStatus() != IssueStatus.ACKNOWLEDGED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Only OPEN or ACKNOWLEDGED issues can be resolved. Current status: " + issue.getStatus());
        }
        
        String previousStatus = issue.getStatus().name();
        UUID stationId = issue.getStationId();
        issue.setStatus(IssueStatus.RESOLVED);
        issue.setDecidedAt(Instant.now());
        issue.setAdminNote(note);
        reportIssueRepository.save(issue);
        
        // Audit log
        writeAuditLog(adminId, adminRole, "ADMIN_RESOLVE_ISSUE", "REPORT_ISSUE", issueId,
                Map.of("previousStatus", previousStatus, "newStatus", "RESOLVED", "note", note));
        
        // Recalculate trust score after resolving issue
        trustScoringService.recalculate(stationId);
        
        log.info("Issue resolved: id={}", issueId);
        return getIssueById(issueId).orElseThrow();
    }

    /**
     * Reject an issue (OPEN/ACKNOWLEDGED -> REJECTED).
     */
    @Transactional
    public AdminIssueResponseDTO rejectIssue(UUID issueId, String reason, UUID adminId, String adminRole) {
        log.info("Admin rejecting issue: id={}, adminId={}", issueId, adminId);
        
        ReportIssueEntity issue = reportIssueRepository.findById(issueId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Issue not found"));
        
        if (issue.getStatus() != IssueStatus.OPEN && issue.getStatus() != IssueStatus.ACKNOWLEDGED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Only OPEN or ACKNOWLEDGED issues can be rejected. Current status: " + issue.getStatus());
        }
        
        String previousStatus = issue.getStatus().name();
        UUID stationId = issue.getStationId();
        issue.setStatus(IssueStatus.REJECTED);
        issue.setDecidedAt(Instant.now());
        issue.setAdminNote(reason);
        reportIssueRepository.save(issue);
        
        // Audit log
        writeAuditLog(adminId, adminRole, "ADMIN_REJECT_ISSUE", "REPORT_ISSUE", issueId,
                Map.of("previousStatus", previousStatus, "newStatus", "REJECTED", "reason", reason));
        
        // Recalculate trust score after rejecting issue (removes penalty)
        trustScoringService.recalculate(stationId);
        
        log.info("Issue rejected: id={}", issueId);
        return getIssueById(issueId).orElseThrow();
    }

    // ========== For Trust Score Calculation (Task 2.3) ==========

    /**
     * Count unresolved issues for a station.
     */
    @Transactional(readOnly = true)
    public long countUnresolvedIssues(UUID stationId) {
        return reportIssueRepository.countUnresolvedByStationId(stationId);
    }

    /**
     * Get unresolved issues for a station.
     */
    @Transactional(readOnly = true)
    public List<ReportIssueEntity> getUnresolvedIssues(UUID stationId) {
        return reportIssueRepository.findUnresolvedByStationId(stationId);
    }

    // ========== Private Helper Methods ==========

    private Map<UUID, String> loadStationNames(List<UUID> stationIds) {
        if (stationIds.isEmpty()) {
            return Map.of();
        }
        
        return stationIds.stream()
                .map(stationId -> stationVersionRepository.findPublishedByStationId(stationId)
                        .map(sv -> Map.entry(stationId, sv.getName()))
                        .orElse(Map.entry(stationId, "Unknown Station")))
                .collect(Collectors.toMap(Map.Entry::getKey, Map.Entry::getValue, (a, b) -> a));
    }

    private Map<UUID, String> loadUserEmails(List<UUID> userIds) {
        if (userIds.isEmpty()) {
            return Map.of();
        }
        
        return userAccountRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(
                        UserAccountEntity::getId,
                        UserAccountEntity::getEmail,
                        (a, b) -> a
                ));
    }

    private IssueResponseDTO buildUserDTO(ReportIssueEntity issue, String stationName) {
        return IssueResponseDTO.builder()
                .id(issue.getId())
                .stationId(issue.getStationId())
                .stationName(stationName)
                .reporterId(issue.getReporterId())
                .category(issue.getCategory())
                .description(issue.getDescription())
                .status(issue.getStatus())
                .createdAt(issue.getCreatedAt())
                .decidedAt(issue.getDecidedAt())
                .adminNote(issue.getAdminNote())
                .build();
    }

    private AdminIssueResponseDTO buildAdminDTO(ReportIssueEntity issue, String stationName, String reporterEmail) {
        return AdminIssueResponseDTO.builder()
                .id(issue.getId())
                .stationId(issue.getStationId())
                .stationName(stationName)
                .reporterId(issue.getReporterId())
                .reporterEmail(reporterEmail)
                .category(issue.getCategory())
                .description(issue.getDescription())
                .status(issue.getStatus())
                .createdAt(issue.getCreatedAt())
                .decidedAt(issue.getDecidedAt())
                .adminNote(issue.getAdminNote())
                .build();
    }

    private void writeAuditLog(UUID actorId, String actorRole, String action, 
                               String entityType, UUID entityId, Map<String, Object> metadata) {
        AuditLogEntity auditLog = AuditLogEntity.builder()
                .actorId(actorId)
                .actorRole(actorRole)
                .action(action)
                .entityType(entityType)
                .entityId(entityId)
                .metadata(metadata)
                .createdAt(Instant.now())
                .build();
        auditLogRepository.save(auditLog);
        log.debug("Audit log written: action={}, entityType={}, entityId={}", action, entityType, entityId);
    }
}

