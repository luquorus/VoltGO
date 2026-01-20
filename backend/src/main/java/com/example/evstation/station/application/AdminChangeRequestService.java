package com.example.evstation.station.application;

import com.example.evstation.api.admin_web.dto.AdminChangeRequestDTO;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.*;
import com.example.evstation.station.infrastructure.jpa.*;
import com.example.evstation.booking.application.ChargerUnitCreationService;
import com.example.evstation.trust.application.TrustScoringService;
import com.example.evstation.verification.application.VerificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AdminChangeRequestService {
    
    private final ChangeRequestJpaRepository changeRequestRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final StationJpaRepository stationRepository;
    private final StationServiceJpaRepository stationServiceRepository;
    private final ChargingPortJpaRepository chargingPortRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final TrustScoringService trustScoringService;
    private final VerificationService verificationService;
    private final ChargerUnitCreationService chargerUnitCreationService;
    
    private static final int HIGH_RISK_THRESHOLD = 60;

    /**
     * Get all change requests with optional status filter
     */
    @Transactional(readOnly = true)
    public Page<AdminChangeRequestDTO> getChangeRequests(ChangeRequestStatus status, Pageable pageable) {
        log.info("Getting change requests: status={}", status);
        
        Page<ChangeRequestEntity> page;
        if (status != null) {
            page = changeRequestRepository.findByStatusOrderByCreatedAtDesc(status, pageable);
        } else {
            page = changeRequestRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
        
        return page.map(this::buildAdminDTO);
    }

    /**
     * Get change requests by status
     */
    @Transactional(readOnly = true)
    public List<AdminChangeRequestDTO> getChangeRequestsByStatus(ChangeRequestStatus status) {
        log.info("Getting change requests by status: {}", status);
        
        List<ChangeRequestEntity> requests = changeRequestRepository.findByStatusOrderByCreatedAtDesc(status);
        return requests.stream()
                .map(this::buildAdminDTO)
                .collect(Collectors.toList());
    }

    /**
     * Get all change requests (no status filter)
     */
    @Transactional(readOnly = true)
    public List<AdminChangeRequestDTO> getAllChangeRequests() {
        log.info("Getting all change requests");
        
        List<ChangeRequestEntity> requests = changeRequestRepository.findAllByOrderByCreatedAtDesc();
        return requests.stream()
                .map(this::buildAdminDTO)
                .collect(Collectors.toList());
    }

    /**
     * Get a specific change request by ID
     */
    @Transactional(readOnly = true)
    public Optional<AdminChangeRequestDTO> getChangeRequest(UUID id) {
        log.info("Getting change request: {}", id);
        return changeRequestRepository.findById(id).map(this::buildAdminDTO);
    }

    /**
     * Approve a change request (PENDING -> APPROVED)
     */
    @Transactional
    public AdminChangeRequestDTO approveChangeRequest(UUID id, String note, UUID adminId, String adminRole) {
        log.info("Approving change request: id={}, adminId={}", id, adminId);
        
        ChangeRequestEntity changeRequest = changeRequestRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found"));
        
        // Validate status
        if (changeRequest.getStatus() != ChangeRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Only PENDING change requests can be approved. Current status: " + changeRequest.getStatus());
        }
        
        // Update status
        changeRequest.setStatus(ChangeRequestStatus.APPROVED);
        changeRequest.setDecidedAt(Instant.now());
        if (note != null && !note.isBlank()) {
            changeRequest.setAdminNote(note);
        }
        changeRequestRepository.save(changeRequest);
        
        // Write audit log
        writeAuditLog(adminId, adminRole, "APPROVE_CHANGE_REQUEST", "CHANGE_REQUEST", id, 
                Map.of(
                        "note", note != null ? note : "",
                        "previousStatus", "PENDING",
                        "newStatus", "APPROVED"
                ));
        
        log.info("Change request approved: id={}", id);
        return buildAdminDTO(changeRequest);
    }

    /**
     * Reject a change request (PENDING -> REJECTED)
     */
    @Transactional
    public AdminChangeRequestDTO rejectChangeRequest(UUID id, String reason, UUID adminId, String adminRole) {
        log.info("Rejecting change request: id={}, adminId={}", id, adminId);
        
        ChangeRequestEntity changeRequest = changeRequestRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found"));
        
        // Validate status
        if (changeRequest.getStatus() != ChangeRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Only PENDING change requests can be rejected. Current status: " + changeRequest.getStatus());
        }
        
        // Update status
        changeRequest.setStatus(ChangeRequestStatus.REJECTED);
        changeRequest.setDecidedAt(Instant.now());
        changeRequest.setAdminNote(reason);
        
        // Also update station_version to REJECTED
        StationVersionEntity stationVersion = stationVersionRepository
                .findById(changeRequest.getProposedStationVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Station version not found"));
        stationVersion.setWorkflowStatus(WorkflowStatus.REJECTED);
        // Clear published_at when rejecting (required by constraint: published_at must be NULL when status != PUBLISHED)
        stationVersion.setPublishedAt(null);
        stationVersionRepository.save(stationVersion);
        
        changeRequestRepository.save(changeRequest);
        
        // Write audit log
        writeAuditLog(adminId, adminRole, "REJECT_CHANGE_REQUEST", "CHANGE_REQUEST", id, 
                Map.of(
                        "reason", reason,
                        "previousStatus", "PENDING",
                        "newStatus", "REJECTED"
                ));
        
        log.info("Change request rejected: id={}", id);
        return buildAdminDTO(changeRequest);
    }

    /**
     * Publish an approved change request (APPROVED -> PUBLISHED)
     * 
     * Rules:
     * - CR must be APPROVED
     * - If CREATE: create station record if not exists, bind proposed station_version.station_id
     * - If UPDATE: bind to existing station
     * - Set old published station_version -> ARCHIVED
     * - Set proposed station_version -> PUBLISHED + published_at
     * - Set CR -> PUBLISHED + decided_at
     */
    @Transactional
    public AdminChangeRequestDTO publishChangeRequest(UUID id, UUID adminId, String adminRole) {
        log.info("Publishing change request: id={}, adminId={}", id, adminId);
        
        ChangeRequestEntity changeRequest = changeRequestRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found"));
        
        // Validate status - must be APPROVED
        if (changeRequest.getStatus() != ChangeRequestStatus.APPROVED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Only APPROVED change requests can be published. Current status: " + changeRequest.getStatus());
        }
        
        // Enforce verification PASS for high-risk CRs
        if (changeRequest.getRiskScore() >= HIGH_RISK_THRESHOLD) {
            if (!verificationService.hasPassedVerificationForCR(id)) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                        "High-risk change request (risk_score >= " + HIGH_RISK_THRESHOLD + 
                        ") requires verification PASS before publishing. " +
                        "Please create a verification task and wait for PASS review.");
            }
            log.info("High-risk CR {} passed verification check", id);
        }
        
        StationVersionEntity proposedVersion = stationVersionRepository
                .findById(changeRequest.getProposedStationVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Proposed station version not found"));
        
        UUID stationId;
        
        if (changeRequest.getType() == ChangeRequestType.CREATE_STATION) {
            // For CREATE_STATION, station was already created when change request was created
            // Just use the stationId from the proposed version
            stationId = proposedVersion.getStationId();
            log.info("Publishing CREATE_STATION: stationId={}", stationId);
        } else {
            // UPDATE_STATION - use existing station ID
            stationId = changeRequest.getStationId();
            if (stationId == null) {
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, 
                        "UPDATE_STATION change request must have stationId");
            }
            log.info("Publishing UPDATE_STATION: stationId={}", stationId);
        }
        
        // CRITICAL: Lock station row to serialize publish operations for the same station.
        // This prevents concurrent publish that could violate unique constraint.
        // Lock is acquired even if no published version exists to ensure atomic operation.
        stationRepository.findByIdForUpdate(stationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, 
                        "Station not found: " + stationId));
        log.debug("Acquired pessimistic lock on station: {}", stationId);
        
        // Archive old published version (if exists)
        Optional<StationVersionEntity> oldPublishedVersion = stationVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED);
        
        if (oldPublishedVersion.isPresent()) {
            StationVersionEntity oldVersion = oldPublishedVersion.get();
            oldVersion.setWorkflowStatus(WorkflowStatus.ARCHIVED);
            oldVersion.setPublishedAt(null); // Clear published_at when archiving (required by check constraint)
            stationVersionRepository.save(oldVersion);
            log.info("Archived old version: versionId={}", oldVersion.getId());
            
            // Audit log for archiving
            writeAuditLog(adminId, adminRole, "ARCHIVE_STATION_VERSION", "STATION_VERSION", oldVersion.getId(),
                    Map.of(
                            "stationId", stationId.toString(),
                            "versionNo", oldVersion.getVersionNo(),
                            "previousStatus", "PUBLISHED",
                            "newStatus", "ARCHIVED"
                    ));
        }
        
        // CRITICAL: Flush to ensure old version is archived in DB BEFORE publishing new one.
        // This prevents unique constraint violation by ensuring DB state is consistent.
        stationVersionRepository.flush();
        log.debug("Flushed repository to ensure old version is archived in DB");
        
        // Publish the proposed version
        proposedVersion.setWorkflowStatus(WorkflowStatus.PUBLISHED);
        proposedVersion.setPublishedAt(Instant.now());
        stationVersionRepository.save(proposedVersion);
        log.info("Published new version: versionId={}", proposedVersion.getId());
        
        // Automatically create charger units from charging ports
        try {
            List<UUID> createdUnitIds = chargerUnitCreationService.createChargerUnitsFromChargingPorts(proposedVersion);
            log.info("Created {} charger units for published station version: {}", 
                    createdUnitIds.size(), proposedVersion.getId());
        } catch (Exception e) {
            log.error("Failed to create charger units for station version: {}", 
                    proposedVersion.getId(), e);
            // Don't fail the publish operation if charger unit creation fails
            // They can be created manually later if needed
        }
        
        // Update change request status
        changeRequest.setStatus(ChangeRequestStatus.PUBLISHED);
        if (changeRequest.getDecidedAt() == null) {
            changeRequest.setDecidedAt(Instant.now());
        }
        changeRequestRepository.save(changeRequest);
        
        // Write audit log for publish
        writeAuditLog(adminId, adminRole, "PUBLISH_STATION_VERSION", "CHANGE_REQUEST", id,
                Map.of(
                        "stationId", stationId.toString(),
                        "stationVersionId", proposedVersion.getId().toString(),
                        "type", changeRequest.getType().name(),
                        "previousStatus", "APPROVED",
                        "newStatus", "PUBLISHED"
                ));
        
        // Recalculate trust score after publishing
        trustScoringService.recalculate(stationId);
        
        log.info("Change request published: id={}, stationId={}", id, stationId);
        return buildAdminDTO(changeRequest);
    }

    // ========== Private Helper Methods ==========
    
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
    
    private AdminChangeRequestDTO buildAdminDTO(ChangeRequestEntity changeRequest) {
        // Load station version
        StationVersionEntity stationVersion = stationVersionRepository
                .findById(changeRequest.getProposedStationVersionId())
                .orElse(null);
        
        // Load submitter email
        String submitterEmail = userAccountRepository.findById(changeRequest.getSubmittedBy())
                .map(UserAccountEntity::getEmail)
                .orElse(null);
        
        // Load audit logs
        List<AuditLogEntity> auditLogs = auditLogRepository
                .findByEntityTypeAndEntityIdOrderByCreatedAtDesc("CHANGE_REQUEST", changeRequest.getId());
        
        AdminChangeRequestDTO.StationDataDTO stationData = null;
        if (stationVersion != null) {
            // Load services and ports
            List<StationServiceEntity> services = stationServiceRepository
                    .findByStationVersionId(stationVersion.getId());
            List<UUID> serviceIds = services.stream().map(StationServiceEntity::getId).toList();
            List<ChargingPortEntity> ports = serviceIds.isEmpty() ? List.of() : 
                    chargingPortRepository.findByStationServiceIds(serviceIds);
            
            // Group ports by service
            Map<UUID, List<ChargingPortEntity>> portsByService = ports.stream()
                    .collect(Collectors.groupingBy(ChargingPortEntity::getStationServiceId));
            
            List<AdminChangeRequestDTO.ServiceDTO> serviceDTOs = services.stream()
                    .map(service -> {
                        List<AdminChangeRequestDTO.ChargingPortDTO> portDTOs = 
                                portsByService.getOrDefault(service.getId(), List.of()).stream()
                                        .map(port -> AdminChangeRequestDTO.ChargingPortDTO.builder()
                                                .powerType(port.getPowerType())
                                                .powerKw(port.getPowerKw())
                                                .count(port.getPortCount())
                                                .build())
                                        .collect(Collectors.toList());
                        
                        return AdminChangeRequestDTO.ServiceDTO.builder()
                                .type(service.getServiceType())
                                .chargingPorts(portDTOs)
                                .build();
                    })
                    .collect(Collectors.toList());
            
            stationData = AdminChangeRequestDTO.StationDataDTO.builder()
                    .name(stationVersion.getName())
                    .address(stationVersion.getAddress())
                    .lat(stationVersion.getLocation().getY())
                    .lng(stationVersion.getLocation().getX())
                    .operatingHours(stationVersion.getOperatingHours())
                    .parking(stationVersion.getParking())
                    .visibility(stationVersion.getVisibility())
                    .publicStatus(stationVersion.getPublicStatus())
                    .services(serviceDTOs)
                    .build();
        }
        
        List<AdminChangeRequestDTO.AuditLogDTO> auditLogDTOs = auditLogs.stream()
                .map(al -> AdminChangeRequestDTO.AuditLogDTO.builder()
                        .action(al.getAction())
                        .actorId(al.getActorId())
                        .actorRole(al.getActorRole())
                        .createdAt(al.getCreatedAt())
                        .metadata(al.getMetadata())
                        .build())
                .collect(Collectors.toList());
        
        // Check verification status (only for high-risk CRs)
        Boolean hasVerificationTask = null;
        Boolean hasPassedVerification = null;
        if (changeRequest.getRiskScore() != null && changeRequest.getRiskScore() >= HIGH_RISK_THRESHOLD) {
            hasVerificationTask = verificationService.hasVerificationTaskForCR(changeRequest.getId());
            hasPassedVerification = verificationService.hasPassedVerificationForCR(changeRequest.getId());
        }
        
        return AdminChangeRequestDTO.builder()
                .id(changeRequest.getId())
                .type(changeRequest.getType())
                .status(changeRequest.getStatus())
                .stationId(changeRequest.getStationId())
                .proposedStationVersionId(changeRequest.getProposedStationVersionId())
                .submittedBy(changeRequest.getSubmittedBy())
                .submitterEmail(submitterEmail)
                .riskScore(changeRequest.getRiskScore())
                .riskReasons(changeRequest.getRiskReasons())
                .adminNote(changeRequest.getAdminNote())
                .createdAt(changeRequest.getCreatedAt())
                .submittedAt(changeRequest.getSubmittedAt())
                .decidedAt(changeRequest.getDecidedAt())
                .hasVerificationTask(hasVerificationTask)
                .hasPassedVerification(hasPassedVerification)
                .stationData(stationData)
                .auditLogs(auditLogDTOs)
                .build();
    }
}

