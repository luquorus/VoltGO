package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.api.dto.BatterySwapCRDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRListDTO;
import com.example.evstation.batteryswap.api.dto.CreateBatterySwapCRDTO;
import com.example.evstation.batteryswap.api.dto.UpdateBatterySwapCRDTO;
import com.example.evstation.batteryswap.domain.ChangeRequestStatus;
import com.example.evstation.batteryswap.domain.ChangeRequestType;
import com.example.evstation.batteryswap.infrastructure.jpa.*;
import com.example.evstation.batteryswap.infrastructure.mapper.BatterySwapVersionMapper;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.risk.application.BatterySwapRiskAssessmentResult;
import com.example.evstation.risk.application.RiskEngineService;
import com.example.evstation.trust.application.TrustScoringService;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationEntity;
import com.example.evstation.station.infrastructure.jpa.StationJpaRepository;
import com.example.evstation.verification.domain.VerificationType;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.hibernate.Hibernate;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class BatterySwapChangeRequestService {

    private static final int VERIFICATION_THRESHOLD = 60;

    private final BatterySwapChangeRequestJpaRepository crRepository;
    private final BatterySwapStationVersionJpaRepository versionRepository;
    private final BatterySwapPileTemplateJpaRepository pileTemplateRepository;
    private final BatterySwapSlotTemplateJpaRepository slotTemplateRepository;
    private final BatterySwapTrustJpaRepository trustRepository;
    private final StationJpaRepository stationRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final RiskEngineService riskEngineService;
    private final SwapStationStateApplyService swapStationStateApplyService;
    private final TrustScoringService trustScoringService;
    private final BatterySwapTrustScoringService batterySwapTrustScoringService;
    private final VerificationTaskJpaRepository verificationTaskRepository;
    private final BatterySwapVersionMapper mapper;

    // ========== EV User Operations ==========

    /**
     * Create a new battery swap change request (DRAFT).
     * Creates: BatterySwapStationVersion (DRAFT) + PileTemplate + SlotTemplate + BatterySwapChangeRequest (DRAFT)
     */
    @Transactional
    public BatterySwapCRDTO createChangeRequest(CreateBatterySwapCRDTO dto, UUID userId) {
        log.info("Creating battery swap CR: type={}, userId={}", dto.getType(), userId);

        validateCreateRequest(dto);

        UUID stationId;
        int versionNo = 1;

        if (dto.getType() == ChangeRequestType.CREATE_BATTERY_SWAP_STATION) {
            StationEntity station = StationEntity.builder()
                    .id(UUID.randomUUID())
                    .providerId(userId)
                    .createdAt(Instant.now())
                    .build();
            stationRepository.save(station);
            stationId = station.getId();
            log.info("Created new station: {}", stationId);
        } else {
            stationId = dto.getStationId();
            if (!stationRepository.existsById(stationId)) {
                throw new BusinessException(ErrorCode.NOT_FOUND, "Station not found: " + stationId);
            }
            Optional<BatterySwapStationVersionEntity> latestPublished =
                    versionRepository.findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED);
            versionNo = latestPublished.map(v -> v.getVersionNo() + 1).orElse(1);
        }

        BatterySwapStationVersionEntity version = BatterySwapStationVersionEntity.builder()
                .id(UUID.randomUUID())
                .stationId(stationId)
                .versionNo(versionNo)
                .workflowStatus(WorkflowStatus.DRAFT)
                .totalBatteries(dto.getTotalBatteries())
                .avgChargePowerKw(dto.getAvgChargePowerKw())
                .operatingHours(dto.getOperatingHours())
                .parkingFee(dto.getParkingFee())
                .note(dto.getNote())
                .createdBy(userId)
                .createdAt(Instant.now())
                .build();
        versionRepository.save(version);
        log.info("Created station version: {}", version.getId());

        List<BatterySwapPileTemplateEntity> pileTemplates = buildPileTemplates(dto, version);
        version.setPileTemplates(pileTemplates);
        versionRepository.save(version);
        for (BatterySwapPileTemplateEntity pile : pileTemplates) {
            pileTemplateRepository.save(pile);
        }
        log.info("Created {} pile templates for version {}", pileTemplates.size(), version.getId());

        BatterySwapChangeRequestEntity cr = BatterySwapChangeRequestEntity.builder()
                .id(UUID.randomUUID())
                .type(dto.getType())
                .status(ChangeRequestStatus.DRAFT)
                .stationId(dto.getType() == ChangeRequestType.UPDATE_BATTERY_SWAP_STATION ? stationId : null)
                .proposedVersionId(version.getId())
                .submittedBy(userId)
                .riskScore(0)
                .riskReasons("[]")
                .createdAt(Instant.now())
                .build();
        crRepository.save(cr);
        log.info("Created battery swap CR: {}", cr.getId());

        writeAuditLog(userId, "EV_USER", "CREATE_BATTERY_SWAP_CR", "BATTERY_SWAP_CHANGE_REQUEST", cr.getId(),
                Map.of(
                        "type", dto.getType().name(),
                        "stationId", stationId.toString(),
                        "versionId", version.getId().toString(),
                        "totalBatteries", dto.getTotalBatteries()
                ));

        version.setPileTemplates(pileTemplates);
        return mapper.toDTO(cr, version);
    }

    /**
     * Submit a DRAFT change request -> PENDING.
     * Runs risk assessment and updates riskScore + riskReasons.
     */
    @Transactional
    public BatterySwapCRDTO submitChangeRequest(UUID crId, UUID userId) {
        log.info("Submitting battery swap CR: id={}, userId={}", crId, userId);

        BatterySwapChangeRequestEntity cr = crRepository.findById(crId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found: " + crId));

        if (!cr.getSubmittedBy().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "You can only submit your own change requests");
        }
        if (cr.getStatus() != ChangeRequestStatus.DRAFT) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Only DRAFT change requests can be submitted. Current status: " + cr.getStatus());
        }

        BatterySwapStationVersionEntity version = versionRepository.findById(cr.getProposedVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Version not found"));

        version.setWorkflowStatus(WorkflowStatus.PENDING);
        version.setSubmittedAt(Instant.now());
        versionRepository.save(version);

        cr.setStatus(ChangeRequestStatus.PENDING);
        cr.setSubmittedAt(Instant.now());

        BatterySwapRiskAssessmentResult riskResult = riskEngineService.assessBatterySwapChangeRequest(cr);
        cr.setRiskScore(riskResult.getRiskScore());
        String riskReasonsJson;
        try {
            riskReasonsJson = new ObjectMapper().registerModule(new com.fasterxml.jackson.datatype.jsr310.JavaTimeModule())
                    .writeValueAsString(riskResult.getRiskReasons().stream().map(r -> r.name()).collect(Collectors.toList()));
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize risk reasons: {}", e.getMessage());
            riskReasonsJson = "[]";
        }
        cr.setRiskReasons(riskReasonsJson);
        crRepository.save(cr);

        log.info("Battery swap CR submitted: id={}, status=PENDING, riskScore={}", crId, riskResult.getRiskScore());

        writeAuditLog(userId, "EV_USER", "SUBMIT_BATTERY_SWAP_CR", "BATTERY_SWAP_CHANGE_REQUEST", crId,
                Map.of(
                        "type", cr.getType().name(),
                        "versionId", version.getId().toString(),
                        "riskScore", cr.getRiskScore(),
                        "riskReasons", cr.getRiskReasons() != null ? cr.getRiskReasons() : "[]"
                ));

        Hibernate.initialize(version.getPileTemplates());
        return mapper.toDTO(cr, version);
    }

    /**
     * List all CRs submitted by the current user.
     */
    @Transactional(readOnly = true)
    public List<BatterySwapCRListDTO> getMyChangeRequests(UUID userId) {
        log.info("Getting battery swap CRs for user: {}", userId);
        return crRepository.findBySubmittedByOrderByCreatedAtDesc(userId).stream()
                .map(mapper::toListDTO)
                .collect(Collectors.toList());
    }

    /**
     * Get a specific CR by ID (only if owned by the user).
     */
    @Transactional(readOnly = true)
    public Optional<BatterySwapCRDTO> getChangeRequest(UUID crId, UUID userId) {
        log.info("Getting battery swap CR: id={}, userId={}", crId, userId);
        return crRepository.findById(crId)
                .filter(cr -> cr.getSubmittedBy().equals(userId))
                .map(cr -> loadAndBuildDTO(cr));
    }

    // ========== Admin Operations ==========

    /**
     * List all CRs with optional status filter.
     */
    @Transactional(readOnly = true)
    public List<BatterySwapCRListDTO> listAll(ChangeRequestStatus status) {
        log.info("Admin listing battery swap CRs: status={}", status);
        List<BatterySwapChangeRequestEntity> results;
        if (status != null) {
            results = crRepository.findByStatus(status);
        } else {
            results = crRepository.findAll();
        }
        return results.stream()
                .map(mapper::toListDTO)
                .collect(Collectors.toList());
    }

    /**
     * Get CR detail by ID (admin).
     */
    @Transactional(readOnly = true)
    public Optional<BatterySwapCRDTO> getChangeRequestAdmin(UUID crId) {
        log.info("Admin getting battery swap CR: id={}", crId);
        return crRepository.findById(crId).map(this::loadAndBuildDTO);
    }

    /**
     * Update a DRAFT change request (admin).
     * Only updates version fields (totalBatteries, avgChargePowerKw, etc.)
     * and optionally replaces pile templates.
     * Status must be DRAFT.
     */
    @Transactional
    public BatterySwapCRDTO updateChangeRequest(UUID crId, UpdateBatterySwapCRDTO dto, UUID adminId) {
        log.info("Admin updating battery swap CR: id={}, adminId={}", crId, adminId);

        BatterySwapChangeRequestEntity cr = crRepository.findById(crId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND,
                        "Change request not found: " + crId));

        if (cr.getStatus() != ChangeRequestStatus.DRAFT) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Only DRAFT change requests can be updated. Current status: " + cr.getStatus());
        }

        BatterySwapStationVersionEntity version = versionRepository.findById(cr.getProposedVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR,
                        "Proposed version not found: " + cr.getProposedVersionId()));

        // Update version fields if provided
        if (dto.getTotalBatteries() != null) {
            version.setTotalBatteries(dto.getTotalBatteries());
        }
        if (dto.getAvgChargePowerKw() != null) {
            version.setAvgChargePowerKw(dto.getAvgChargePowerKw());
        }
        if (dto.getOperatingHours() != null) {
            version.setOperatingHours(dto.getOperatingHours());
        }
        if (dto.getParkingFee() != null) {
            version.setParkingFee(dto.getParkingFee());
        }
        if (dto.getNote() != null) {
            version.setNote(dto.getNote());
        }
        versionRepository.save(version);

        // Replace pile templates if provided — delete old ones from DB first
        // (slots, then piles) so the unique-constraint (station_version_id, pile_index) is freed,
        // then clear the in-memory collection so Hibernate doesn't try to reconcile orphaned entities.
        if (dto.getPileTemplates() != null) {
            pileTemplateRepository.deleteSlotTemplatesByStationVersionId(version.getId());
            pileTemplateRepository.deletePileTemplatesByStationVersionId(version.getId());
            version.getPileTemplates().clear();
            List<BatterySwapPileTemplateEntity> newPiles = buildPileTemplatesFromUpdate(dto, version);
            version.getPileTemplates().addAll(newPiles);
            versionRepository.save(version);
        }

        // Update admin note on CR if provided
        if (dto.getAdminNote() != null) {
            cr.setAdminNote(dto.getAdminNote());
            crRepository.save(cr);
        }

        Hibernate.initialize(version.getPileTemplates());
        return mapper.toDTO(cr, version);
    }

    private List<BatterySwapPileTemplateEntity> buildPileTemplatesFromUpdate(
            UpdateBatterySwapCRDTO dto, BatterySwapStationVersionEntity version) {

        List<BatterySwapPileTemplateEntity> piles = dto.getPileTemplates().stream()
                .sorted((a, b) -> Integer.compare(a.getPileIndex(), b.getPileIndex()))
                .map(pileDto -> {
                    BatterySwapPileTemplateEntity pile = BatterySwapPileTemplateEntity.builder()
                            .id(UUID.randomUUID())
                            .pileIndex(pileDto.getPileIndex())
                            .slotsPerPile(pileDto.getSlotsPerPile())
                            .stationVersion(version)
                            .slotTemplates(new java.util.ArrayList<>())
                            .build();

                    if (pileDto.getSlots() != null) {
                        for (UpdateBatterySwapCRDTO.SlotTemplateDTO slotDto : pileDto.getSlots()) {
                            BatterySwapSlotTemplateEntity slot = BatterySwapSlotTemplateEntity.builder()
                                    .id(UUID.randomUUID())
                                    .slotIndex(slotDto.getSlotIndex())
                                    .batteryCapacityKwh(slotDto.getBatteryCapacityKwh())
                                    .pileTemplate(pile)
                                    .build();
                            pile.getSlotTemplates().add(slot);
                        }
                    }
                    return pile;
                })
                .collect(Collectors.toList());

        return piles;
    }

    /**
     * Approve a PENDING CR: PENDING -> APPROVED.
     */
    @Transactional
    public BatterySwapCRDTO approveChangeRequest(UUID crId, UUID adminId, String note) {
        log.info("Admin approving battery swap CR: id={}, adminId={}", crId, adminId);

        BatterySwapChangeRequestEntity cr = crRepository.findById(crId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found: " + crId));

        if (cr.getStatus() != ChangeRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Only PENDING change requests can be approved. Current status: " + cr.getStatus());
        }

        cr.setStatus(ChangeRequestStatus.APPROVED);
        cr.setAdminNote(note);
        cr.setDecidedAt(Instant.now());
        crRepository.save(cr);

        BatterySwapStationVersionEntity version = versionRepository.findById(cr.getProposedVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Version not found"));
        version.setWorkflowStatus(WorkflowStatus.APPROVED);
        versionRepository.save(version);

        writeAuditLog(adminId, "ADMIN", "APPROVE_BATTERY_SWAP_CR", "BATTERY_SWAP_CHANGE_REQUEST", crId,
                Map.of(
                        "type", cr.getType().name(),
                        "versionId", version.getId().toString(),
                        "adminNote", note != null ? note : ""
                ));

        Hibernate.initialize(version.getPileTemplates());
        return mapper.toDTO(cr, version);
    }

    /**
     * Reject a PENDING CR: PENDING -> REJECTED.
     */
    @Transactional
    public BatterySwapCRDTO rejectChangeRequest(UUID crId, UUID adminId, String reason) {
        log.info("Admin rejecting battery swap CR: id={}, adminId={}", crId, adminId);

        BatterySwapChangeRequestEntity cr = crRepository.findById(crId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found: " + crId));

        if (cr.getStatus() != ChangeRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Only PENDING change requests can be rejected. Current status: " + cr.getStatus());
        }

        cr.setStatus(ChangeRequestStatus.REJECTED);
        cr.setAdminNote(reason);
        cr.setDecidedAt(Instant.now());
        crRepository.save(cr);

        BatterySwapStationVersionEntity version = versionRepository.findById(cr.getProposedVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Version not found"));
        version.setWorkflowStatus(WorkflowStatus.REJECTED);
        versionRepository.save(version);

        writeAuditLog(adminId, "ADMIN", "REJECT_BATTERY_SWAP_CR", "BATTERY_SWAP_CHANGE_REQUEST", crId,
                Map.of(
                        "type", cr.getType().name(),
                        "versionId", version.getId().toString(),
                        "reason", reason != null ? reason : ""
                ));

        Hibernate.initialize(version.getPileTemplates());
        return mapper.toDTO(cr, version);
    }

    /**
     * Publish an APPROVED CR: APPROVED -> PUBLISHED.
     * If riskScore >= 60, creates a VerificationTask (BATTERY_SWAP type).
     * Applies the version to operational state via SwapStationStateApplyService.
     */
    @Transactional
    public BatterySwapCRDTO publishChangeRequest(UUID crId, UUID adminId) {
        log.info("Admin publishing battery swap CR: id={}, adminId={}", crId, adminId);

        BatterySwapChangeRequestEntity cr = crRepository.findById(crId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Change request not found: " + crId));

        if (cr.getStatus() != ChangeRequestStatus.APPROVED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Only APPROVED change requests can be published. Current status: " + cr.getStatus());
        }

        BatterySwapStationVersionEntity version = versionRepository.findById(cr.getProposedVersionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR, "Version not found"));

        StationEntity station = stationRepository.findByIdForUpdate(version.getStationId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Station not found"));

        if (cr.getRiskScore() >= VERIFICATION_THRESHOLD) {
            log.info("CR {} has riskScore={} >= {}, creating verification task", crId, cr.getRiskScore(), VERIFICATION_THRESHOLD);
            createVerificationTask(cr, version, station);
        }

        version.setWorkflowStatus(WorkflowStatus.PUBLISHED);
        version.setPublishedAt(Instant.now());
        versionRepository.save(version);

        cr.setStatus(ChangeRequestStatus.PUBLISHED);
        cr.setDecidedAt(Instant.now());
        crRepository.save(cr);

        try {
            swapStationStateApplyService.applyForSwapVersion(version);
        } catch (Exception e) {
            log.error("Error applying swap version to operational state: {}", e.getMessage(), e);
        }

        try {
            initializeSwapTrustIfNeeded(version.getStationId());
        } catch (Exception e) {
            log.warn("SwapTrustScoringService not yet implemented or error: {}", e.getMessage());
        }

        try {
            trustScoringService.recalculate(version.getStationId());
        } catch (Exception e) {
            log.warn("TrustScoringService.recalculate failed: {}", e.getMessage());
        }

        writeAuditLog(adminId, "ADMIN", "PUBLISH_BATTERY_SWAP_CR", "BATTERY_SWAP_CHANGE_REQUEST", crId,
                Map.of(
                        "type", cr.getType().name(),
                        "versionId", version.getId().toString(),
                        "stationId", version.getStationId().toString(),
                        "riskScore", cr.getRiskScore(),
                        "riskScoreThreshold", VERIFICATION_THRESHOLD,
                        "verificationRequired", cr.getRiskScore() >= VERIFICATION_THRESHOLD
                ));

        Hibernate.initialize(version.getPileTemplates());
        return mapper.toDTO(cr, version);
    }

    // ========== Private Helpers ==========

    private void validateCreateRequest(CreateBatterySwapCRDTO dto) {
        if (dto.getType() == ChangeRequestType.UPDATE_BATTERY_SWAP_STATION && dto.getStationId() == null) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "stationId is required for UPDATE_BATTERY_SWAP_STATION");
        }
        if (dto.getType() == ChangeRequestType.CREATE_BATTERY_SWAP_STATION && dto.getStationId() != null) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "stationId must be null for CREATE_BATTERY_SWAP_STATION");
        }
        if (dto.getTotalBatteries() == null || dto.getTotalBatteries() <= 0) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "totalBatteries must be > 0");
        }
        if (dto.getAvgChargePowerKw() == null || dto.getAvgChargePowerKw().signum() <= 0) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "avgChargePowerKw must be > 0");
        }
    }

    private List<BatterySwapPileTemplateEntity> buildPileTemplates(CreateBatterySwapCRDTO dto, BatterySwapStationVersionEntity version) {
        List<BatterySwapPileTemplateEntity> piles;

        if (dto.getPileTemplates() != null && !dto.getPileTemplates().isEmpty()) {
            piles = dto.getPileTemplates().stream()
                    .sorted((a, b) -> Integer.compare(a.getPileIndex(), b.getPileIndex()))
                    .map(pileDto -> {
                        BatterySwapPileTemplateEntity pile = BatterySwapPileTemplateEntity.builder()
                                .id(UUID.randomUUID())
                                .pileIndex(pileDto.getPileIndex())
                                .slotsPerPile(pileDto.getSlotsPerPile())
                                .stationVersion(version)
                                .slotTemplates(new java.util.ArrayList<>())
                                .build();

                        if (pileDto.getSlots() != null) {
                            for (CreateBatterySwapCRDTO.SlotTemplateDTO slotDto : pileDto.getSlots()) {
                                BatterySwapSlotTemplateEntity slot = BatterySwapSlotTemplateEntity.builder()
                                        .id(UUID.randomUUID())
                                        .slotIndex(slotDto.getSlotIndex())
                                        .batteryCapacityKwh(slotDto.getBatteryCapacityKwh())
                                        .pileTemplate(pile)
                                        .build();
                                pile.getSlotTemplates().add(slot);
                            }
                        }
                        return pile;
                    })
                    .collect(Collectors.toList());
        } else {
            int totalBatteries = dto.getTotalBatteries();
            int slotsPerPile = 6;
            int numPiles = (int) Math.ceil((double) totalBatteries / slotsPerPile);
            piles = new java.util.ArrayList<>();
            for (int i = 0; i < numPiles; i++) {
                int slotsInThisPile = Math.min(slotsPerPile, totalBatteries - (i * slotsPerPile));
                BatterySwapPileTemplateEntity pile = BatterySwapPileTemplateEntity.builder()
                        .id(UUID.randomUUID())
                        .pileIndex(i + 1)
                        .slotsPerPile(slotsInThisPile)
                        .stationVersion(version)
                        .slotTemplates(new java.util.ArrayList<>())
                        .build();

                for (int j = 0; j < slotsInThisPile; j++) {
                    BatterySwapSlotTemplateEntity slot = BatterySwapSlotTemplateEntity.builder()
                            .id(UUID.randomUUID())
                            .slotIndex(j)
                            .batteryCapacityKwh(BigDecimal.valueOf(60.0))
                            .pileTemplate(pile)
                            .build();
                    pile.getSlotTemplates().add(slot);
                }
                piles.add(pile);
            }
        }

        return piles;
    }

    private BatterySwapCRDTO loadAndBuildDTO(BatterySwapChangeRequestEntity cr) {
        BatterySwapStationVersionEntity version = cr.getProposedVersion();
        if (version != null && version.getPileTemplates() != null) {
            Hibernate.initialize(version.getPileTemplates());
        }
        return mapper.toDTO(cr, version);
    }

    private void createVerificationTask(BatterySwapChangeRequestEntity cr,
                                        BatterySwapStationVersionEntity version,
                                        StationEntity station) {
        log.info("Creating verification task for CR {} (riskScore={})", cr.getId(), cr.getRiskScore());

        Map<String, Object> snapshot = Map.of(
                "totalBatteries", version.getTotalBatteries(),
                "avgChargePowerKw", version.getAvgChargePowerKw(),
                "pileCount", version.getPileTemplates() != null ? version.getPileTemplates().size() : 0,
                "slotCount", version.getPileTemplates() != null
                        ? version.getPileTemplates().stream().mapToInt(p -> p.getSlotsPerPile()).sum()
                        : 0,
                "operatingHours", version.getOperatingHours() != null ? version.getOperatingHours() : "",
                "parkingFee", version.getParkingFee() != null ? version.getParkingFee().doubleValue() : 0.0
        );

        String snapshotJson;
        try {
            snapshotJson = new ObjectMapper().registerModule(new com.fasterxml.jackson.datatype.jsr310.JavaTimeModule())
                    .writeValueAsString(snapshot);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize battery swap station snapshot: {}", e.getMessage());
            snapshotJson = "{}";
        }

        Instant slaDue = Instant.now().plusSeconds(7 * 24 * 3600L);

        VerificationTaskEntity task = VerificationTaskEntity.builder()
                .id(UUID.randomUUID())
                .stationId(version.getStationId())
                .changeRequestId(cr.getId())
                .priority(2)
                .slaDueAt(slaDue)
                .status(com.example.evstation.verification.domain.VerificationTaskStatus.OPEN)
                .verificationType(VerificationType.BATTERY_SWAP)
                .batterySwapChangeRequestId(cr.getId())
                .batterySwapStationSnapshot(snapshotJson)
                .createdAt(Instant.now())
                .build();

        verificationTaskRepository.save(task);
        log.info("VerificationTask created: id={} for CR={}, stationId={}", task.getId(), cr.getId(), version.getStationId());
    }

    private void initializeSwapTrustIfNeeded(UUID stationId) {
        batterySwapTrustScoringService.initializeForStation(stationId);
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
