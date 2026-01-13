package com.example.evstation.verification.application;

import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.collaborator.application.ContractPolicyService;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.infrastructure.jpa.*;
import com.example.evstation.trust.application.TrustScoringService;
import com.example.evstation.verification.api.dto.*;
import com.example.evstation.verification.domain.VerificationResult;
import com.example.evstation.verification.domain.VerificationTaskStatus;
import com.example.evstation.verification.infrastructure.jpa.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class VerificationService {
    
    private static final int MAX_CHECKIN_DISTANCE_METERS = 200;
    
    private final VerificationTaskJpaRepository taskRepository;
    private final VerificationCheckinJpaRepository checkinRepository;
    private final VerificationReviewJpaRepository reviewRepository;
    private final StationJpaRepository stationRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final CollaboratorProfileJpaRepository collaboratorRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final ContractPolicyService contractPolicyService;
    private final TrustScoringService trustScoringService;
    private final EntityManager entityManager;
    private final Clock clock;

    // ========== Admin Operations ==========

    /**
     * Create a verification task (Admin only)
     */
    @Transactional
    public VerificationTaskDTO createTask(CreateTaskDTO dto, UUID adminId, String adminRole) {
        log.info("Creating verification task: stationId={}", dto.getStationId());
        
        // Verify station exists
        if (!stationRepository.existsById(dto.getStationId())) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "Station not found");
        }
        
        VerificationTaskEntity task = VerificationTaskEntity.builder()
                .stationId(dto.getStationId())
                .changeRequestId(dto.getChangeRequestId())
                .priority(dto.getPriority() != null ? dto.getPriority() : 3)
                .slaDueAt(dto.getSlaDueAt())
                .status(VerificationTaskStatus.OPEN)
                .createdAt(Instant.now(clock))
                .build();
        
        taskRepository.save(task);
        
        writeAuditLog(adminId, adminRole, "CREATE_VERIFICATION_TASK", "VERIFICATION_TASK", task.getId(),
                Map.of("stationId", dto.getStationId().toString(),
                       "priority", task.getPriority()));
        
        log.info("Verification task created: id={}", task.getId());
        return buildTaskDTO(task);
    }

    /**
     * Assign task to collaborator by email (Admin only) - backward compatibility
     */
    @Transactional
    public VerificationTaskDTO assignTask(UUID taskId, AssignTaskDTO dto, UUID adminId, String adminRole) {
        log.info("Assigning task: taskId={}, collaboratorEmail={}", taskId, dto.getCollaboratorEmail());
        
        // Find collaborator by email
        UserAccountEntity user = userAccountRepository.findByEmail(dto.getCollaboratorEmail())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "User not found with email: " + dto.getCollaboratorEmail()));
        
        return assignTaskToUser(taskId, user, adminId, adminRole, null);
    }

    /**
     * Assign task to collaborator by user ID (Admin only) - preferred method from candidates list
     */
    @Transactional
    public VerificationTaskDTO assignTaskByUserId(UUID taskId, UUID collaboratorUserId, UUID adminId, String adminRole) {
        log.info("Assigning task: taskId={}, collaboratorUserId={}", taskId, collaboratorUserId);
        
        // Find collaborator by user ID
        UserAccountEntity user = userAccountRepository.findById(collaboratorUserId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "User not found with ID: " + collaboratorUserId));
        
        // Compute distance for audit log
        VerificationTaskEntity task = taskRepository.findById(taskId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Task not found"));
        
        Integer distance = computeDistanceForAssignment(task.getStationId(), collaboratorUserId);
        
        return assignTaskToUser(taskId, user, adminId, adminRole, distance);
    }

    private VerificationTaskDTO assignTaskToUser(UUID taskId, UserAccountEntity user, UUID adminId, String adminRole, Integer distanceMeters) {
        VerificationTaskEntity task = taskRepository.findById(taskId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Task not found"));
        
        if (task.getStatus() != VerificationTaskStatus.OPEN) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Can only assign OPEN tasks. Current status: " + task.getStatus());
        }
        
        if (user.getRole() != Role.COLLABORATOR) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "User must have COLLABORATOR role. Found role: " + user.getRole());
        }
        
        // Verify collaborator has profile
        if (!collaboratorRepository.existsByUserAccountId(user.getId())) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Collaborator profile not found for user: " + user.getEmail());
        }
        
        // Verify contract is active
        contractPolicyService.requireActiveContract(user.getId());
        
        task.setAssignedTo(user.getId());
        task.setStatus(VerificationTaskStatus.ASSIGNED);
        taskRepository.save(task);
        
        Map<String, Object> metadata = new HashMap<>();
        metadata.put("assignedTo", user.getId().toString());
        metadata.put("assignedToEmail", user.getEmail());
        if (distanceMeters != null) {
            metadata.put("distanceMeters", distanceMeters);
        }
        
        writeAuditLog(adminId, adminRole, "ASSIGN_VERIFICATION_TASK", "VERIFICATION_TASK", taskId, metadata);
        
        log.info("Task assigned: taskId={}, assignedTo={} ({})", taskId, user.getId(), user.getEmail());
        return buildTaskDTO(task);
    }

    private Integer computeDistanceForAssignment(UUID stationId, UUID collaboratorUserId) {
        try {
            // Get collaborator location
            var profile = collaboratorRepository.findByUserAccountId(collaboratorUserId);
            if (profile.isEmpty() || profile.get().getCurrentLocation() == null) {
                return null;
            }
            
            Double collabLat = profile.get().getLatitude();
            Double collabLng = profile.get().getLongitude();
            
            // Get station location
            var stationVersion = stationVersionRepository.findPublishedByStationId(stationId);
            if (stationVersion.isEmpty() || stationVersion.get().getLocation() == null) {
                return null;
            }
            
            Double stationLat = stationVersion.get().getLocation().getY();
            Double stationLng = stationVersion.get().getLocation().getX();
            
            String sql = """
                SELECT CAST(ST_Distance(
                    CAST(ST_SetSRID(ST_MakePoint(?1, ?2), 4326) AS geography),
                    CAST(ST_SetSRID(ST_MakePoint(?3, ?4), 4326) AS geography)
                ) AS INTEGER) as distance
                """;
            
            Query query = entityManager.createNativeQuery(sql);
            query.setParameter(1, stationLng);
            query.setParameter(2, stationLat);
            query.setParameter(3, collabLng);
            query.setParameter(4, collabLat);
            
            Object result = query.getSingleResult();
            return result != null ? ((Number) result).intValue() : null;
        } catch (Exception e) {
            log.warn("Failed to compute distance for assignment: {}", e.getMessage());
            return null;
        }
    }

    /**
     * Get tasks by status (Admin)
     */
    @Transactional(readOnly = true)
    public Page<VerificationTaskDTO> getTasksByStatus(VerificationTaskStatus status, Pageable pageable) {
        Page<VerificationTaskEntity> page;
        if (status != null) {
            page = taskRepository.findByStatusOrderByCreatedAtDesc(status, pageable);
        } else {
            page = taskRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
        return page.map(this::buildTaskDTO);
    }

    /**
     * Get task by ID with full details (Admin)
     */
    @Transactional(readOnly = true)
    public Optional<VerificationTaskDTO> getTaskById(UUID taskId) {
        return taskRepository.findById(taskId).map(this::buildTaskDTO);
    }

    /**
     * Review task (Admin only)
     */
    @Transactional
    public VerificationTaskDTO reviewTask(UUID taskId, ReviewTaskDTO dto, UUID adminId, String adminRole) {
        log.info("Reviewing task: taskId={}, result={}", taskId, dto.getResult());
        
        VerificationTaskEntity task = taskRepository.findById(taskId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Task not found"));
        
        if (task.getStatus() != VerificationTaskStatus.SUBMITTED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Can only review SUBMITTED tasks. Current status: " + task.getStatus());
        }
        
        // Create review
        VerificationReviewEntity review = VerificationReviewEntity.builder()
                .taskId(taskId)
                .result(dto.getResult())
                .adminNote(dto.getAdminNote())
                .reviewedAt(Instant.now(clock))
                .reviewedBy(adminId)
                .build();
        
        reviewRepository.save(review);
        
        // Update task status
        task.setStatus(VerificationTaskStatus.REVIEWED);
        taskRepository.save(task);
        
        // Recalculate trust score
        trustScoringService.recalculate(task.getStationId());
        
        writeAuditLog(adminId, adminRole, "REVIEW_VERIFICATION_TASK", "VERIFICATION_TASK", taskId,
                Map.of("result", dto.getResult().name(),
                       "adminNote", dto.getAdminNote() != null ? dto.getAdminNote() : "",
                       "stationId", task.getStationId().toString()));
        
        log.info("Task reviewed: taskId={}, result={}", taskId, dto.getResult());
        return buildTaskDTO(task);
    }

    // ========== Collaborator Mobile Operations ==========

    /**
     * Get tasks for collaborator mobile
     */
    @Transactional(readOnly = true)
    public List<VerificationTaskDTO> getTasksForCollaboratorMobile(UUID userId, List<VerificationTaskStatus> statuses) {
        return taskRepository.findByAssignedToAndStatusIn(userId, statuses)
                .stream()
                .map(this::buildTaskDTO)
                .collect(Collectors.toList());
    }

    /**
     * Check-in at station location (Collaborator Mobile)
     */
    @Transactional
    public VerificationTaskDTO checkIn(UUID taskId, com.example.evstation.verification.api.dto.CheckinDTO dto, UUID userId) {
        log.info("Check-in: taskId={}, userId={}, lat={}, lng={}", taskId, userId, dto.getLat(), dto.getLng());
        
        VerificationTaskEntity task = taskRepository.findById(taskId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Task not found"));
        
        // Validate task status
        if (task.getStatus() != VerificationTaskStatus.ASSIGNED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Can only check-in for ASSIGNED tasks. Current status: " + task.getStatus());
        }
        
        // Validate assignment
        if (!task.getAssignedTo().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "Task is not assigned to you");
        }
        
        // Check contract is active
        contractPolicyService.requireActiveContract(userId);
        
        // Calculate distance to station
        int distance = calculateDistanceToStation(task.getStationId(), dto.getLat(), dto.getLng());
        
        if (distance > MAX_CHECKIN_DISTANCE_METERS) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    String.format("Too far from station. Distance: %dm, Maximum allowed: %dm", 
                            distance, MAX_CHECKIN_DISTANCE_METERS));
        }
        
        // Create check-in record
        VerificationCheckinEntity checkin = VerificationCheckinEntity.builder()
                .taskId(taskId)
                .checkinLat(BigDecimal.valueOf(dto.getLat()))
                .checkinLng(BigDecimal.valueOf(dto.getLng()))
                .checkedInAt(Instant.now(clock))
                .distanceM(distance)
                .deviceNote(dto.getDeviceNote())
                .build();
        
        checkinRepository.save(checkin);
        
        // Update task status
        task.setStatus(VerificationTaskStatus.CHECKED_IN);
        taskRepository.save(task);
        
        writeAuditLog(userId, "COLLABORATOR", "CHECKIN_VERIFICATION_TASK", "VERIFICATION_TASK", taskId,
                Map.of("lat", dto.getLat(),
                       "lng", dto.getLng(),
                       "distance_m", distance,
                       "stationId", task.getStationId().toString()));
        
        log.info("Check-in completed: taskId={}, distance={}m", taskId, distance);
        return buildTaskDTO(task);
    }


    // ========== Collaborator Web Operations ==========

    /**
     * Get tasks with filters (Collaborator Web)
     */
    @Transactional(readOnly = true)
    public Page<VerificationTaskDTO> getTasksForCollaboratorWeb(
            UUID userId, 
            VerificationTaskStatus status, 
            Integer priority, 
            Instant slaDueBefore,
            Pageable pageable) {
        
        // Use appropriate method based on filters
        if (status != null) {
            return taskRepository.findByAssignedToAndStatusOrderByPriorityAscSlaDueAtAscCreatedAtDesc(
                    userId, status, pageable).map(this::buildTaskDTO);
        } else {
            return taskRepository.findByAssignedToOrderByPriorityAscSlaDueAtAscCreatedAtDesc(
                    userId, pageable).map(this::buildTaskDTO);
        }
    }

    /**
     * Get task history (reviewed tasks) for Collaborator Web
     */
    @Transactional(readOnly = true)
    public Page<VerificationTaskDTO> getTaskHistory(UUID userId, Pageable pageable) {
        return taskRepository.findReviewedByAssignedTo(userId, pageable)
                .map(this::buildTaskDTO);
    }

    /**
     * Get KPI for collaborator (Collaborator Web)
     */
    @Transactional(readOnly = true)
    public CollaboratorKpiDTO getKpi(UUID userId) {
        // Get start of current month
        LocalDate now = LocalDate.now(clock);
        LocalDate startOfMonth = now.withDayOfMonth(1);
        Instant since = startOfMonth.atStartOfDay(ZoneOffset.UTC).toInstant();
        
        List<Object[]> results = reviewRepository.countByResultForCollaborator(userId, since);
        
        int passCount = 0;
        int failCount = 0;
        
        for (Object[] row : results) {
            VerificationResult result = (VerificationResult) row[0];
            long count = (Long) row[1];
            if (result == VerificationResult.PASS) {
                passCount = (int) count;
            } else {
                failCount = (int) count;
            }
        }
        
        int total = passCount + failCount;
        double passRate = total > 0 ? (double) passCount / total * 100 : 0;
        
        return CollaboratorKpiDTO.builder()
                .totalReviewed(total)
                .passCount(passCount)
                .failCount(failCount)
                .passRate(Math.round(passRate * 100.0) / 100.0)
                .period(now.format(DateTimeFormatter.ofPattern("yyyy-MM")))
                .build();
    }

    // ========== Policy Methods ==========

    /**
     * Check if high-risk CR has passed verification (for publish enforcement)
     */
    @Transactional(readOnly = true)
    public boolean hasPassedVerificationForCR(UUID changeRequestId) {
        return taskRepository.hasPassedVerification(changeRequestId);
    }

    /**
     * Check if task exists for CR
     */
    @Transactional(readOnly = true)
    public boolean hasVerificationTaskForCR(UUID changeRequestId) {
        return taskRepository.findByChangeRequestId(changeRequestId).isPresent();
    }

    // ========== Helper Methods ==========

    private int calculateDistanceToStation(UUID stationId, double lat, double lng) {
        // Use PostGIS ST_Distance to calculate distance in meters
        // Note: Using CAST() instead of :: to avoid confusion with named parameter prefix
        String sql = """
            SELECT CAST(ST_Distance(
                CAST(sv.location AS geography),
                CAST(ST_SetSRID(ST_MakePoint(?1, ?2), 4326) AS geography)
            ) AS INTEGER) as distance
            FROM station_version sv
            WHERE sv.station_id = ?3
            AND sv.workflow_status = 'PUBLISHED'
            """;
        
        Query query = entityManager.createNativeQuery(sql);
        query.setParameter(1, lng);
        query.setParameter(2, lat);
        query.setParameter(3, stationId);
        
        try {
            Object result = query.getSingleResult();
            return result != null ? ((Number) result).intValue() : Integer.MAX_VALUE;
        } catch (Exception e) {
            log.warn("Failed to calculate distance for station {}: {}", stationId, e.getMessage());
            return Integer.MAX_VALUE;
        }
    }

    private VerificationTaskDTO buildTaskDTO(VerificationTaskEntity task) {
        // Get station name
        String stationName = stationVersionRepository.findPublishedByStationId(task.getStationId())
                .map(StationVersionEntity::getName)
                .orElse(null);
        
        // Get assigned user email
        String assignedToEmail = task.getAssignedTo() != null 
                ? userAccountRepository.findById(task.getAssignedTo())
                    .map(UserAccountEntity::getEmail)
                    .orElse(null)
                : null;
        
        // Build nested DTOs
        VerificationTaskDTO.CheckinDTO checkinDTO = checkinRepository.findByTaskId(task.getId())
                .map(c -> VerificationTaskDTO.CheckinDTO.builder()
                        .lat(c.getCheckinLat().doubleValue())
                        .lng(c.getCheckinLng().doubleValue())
                        .checkedInAt(c.getCheckedInAt())
                        .distanceM(c.getDistanceM())
                        .deviceNote(c.getDeviceNote())
                        .build())
                .orElse(null);
        
        VerificationTaskDTO.ReviewDTO reviewDTO = reviewRepository.findByTaskId(task.getId())
                .map(r -> VerificationTaskDTO.ReviewDTO.builder()
                        .result(r.getResult().name())
                        .adminNote(r.getAdminNote())
                        .reviewedAt(r.getReviewedAt())
                        .reviewedBy(r.getReviewedBy().toString())
                        .build())
                .orElse(null);
        
        return VerificationTaskDTO.builder()
                .id(task.getId().toString())
                .stationId(task.getStationId().toString())
                .stationName(stationName)
                .changeRequestId(task.getChangeRequestId() != null ? task.getChangeRequestId().toString() : null)
                .priority(task.getPriority())
                .slaDueAt(task.getSlaDueAt())
                .assignedTo(task.getAssignedTo() != null ? task.getAssignedTo().toString() : null)
                .assignedToEmail(assignedToEmail)
                .status(task.getStatus())
                .createdAt(task.getCreatedAt())
                .checkin(checkinDTO)
                .review(reviewDTO)
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
                .createdAt(Instant.now(clock))
                .build();
        auditLogRepository.save(auditLog);
        log.debug("Audit log written: action={}, entityType={}, entityId={}", action, entityType, entityId);
    }
}

