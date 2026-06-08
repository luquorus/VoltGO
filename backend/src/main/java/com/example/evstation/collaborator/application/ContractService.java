package com.example.evstation.collaborator.application;

import com.example.evstation.collaborator.api.dto.ContractDTO;
import com.example.evstation.collaborator.api.dto.CreateContractDTO;
import com.example.evstation.collaborator.api.dto.UpdateContractDTO;
import com.example.evstation.collaborator.domain.ContractStatus;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.ContractEntity;
import com.example.evstation.collaborator.infrastructure.jpa.ContractJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ContractService {
    
    private final ContractJpaRepository contractRepository;
    private final CollaboratorProfileJpaRepository collaboratorRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final Clock clock;
    private final com.example.evstation.notification.application.NotificationService notificationService;
    private final com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository userAccountRepository;

    /**
     * Create a new contract for a collaborator.
     */
    @Transactional
    public ContractDTO createContract(CreateContractDTO dto, UUID adminId, String adminRole) {
        log.info("Creating contract: collaboratorId={}, startDate={}, endDate={}", 
                dto.getCollaboratorId(), dto.getStartDate(), dto.getEndDate());
        
        // Verify collaborator exists
        CollaboratorProfileEntity collaborator = collaboratorRepository.findById(dto.getCollaboratorId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Collaborator not found"));
        
        // Validate dates
        if (dto.getEndDate().isBefore(dto.getStartDate())) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "End date must be after or equal to start date");
        }
        
        // Create contract
        ContractEntity contract = ContractEntity.builder()
                .collaboratorId(dto.getCollaboratorId())
                .region(dto.getRegion())
                .startDate(dto.getStartDate())
                .endDate(dto.getEndDate())
                .status(ContractStatus.ACTIVE)
                .note(dto.getNote())
                .createdAt(Instant.now(clock))
                .build();
        
        contractRepository.save(contract);
        
        // Audit log
        writeAuditLog(adminId, adminRole, "CREATE_CONTRACT", "CONTRACT", contract.getId(),
                Map.of(
                        "collaboratorId", dto.getCollaboratorId().toString(),
                        "collaboratorName", collaborator.getFullName() != null ? collaborator.getFullName() : "",
                        "startDate", dto.getStartDate().toString(),
                        "endDate", dto.getEndDate().toString(),
                        "region", dto.getRegion() != null ? dto.getRegion() : ""
                ));
        
        log.info("Contract created: id={}", contract.getId());

        // Send notification to collaborator
        try {
            String email = userAccountRepository.findById(collaborator.getUserAccountId())
                    .map(u -> u.getEmail()).orElse(null);
            notificationService.send(com.example.evstation.notification.api.dto.CreateNotificationDTO.builder()
                    .recipientId(collaborator.getUserAccountId())
                    .type(com.example.evstation.notification.domain.NotificationType.CONTRACT_CREATED)
                    .category(com.example.evstation.notification.domain.NotificationCategory.CONTRACT)
                    .title("New Contract Created")
                    .body("A new VoltGo Collaborator contract has been created for you. Region: " + (dto.getRegion() != null ? dto.getRegion() : "N/A") + ". Period: " + dto.getStartDate() + " to " + dto.getEndDate())
                    .data(java.util.Map.of(
                            "contractId", contract.getId().toString(),
                            "region", dto.getRegion() != null ? dto.getRegion() : "",
                            "startDate", dto.getStartDate().toString(),
                            "endDate", dto.getEndDate().toString()
                    ))
                    .referenceId(contract.getId())
                    .referenceType("CONTRACT")
                    .build());
        } catch (Exception e) {
            log.warn("Failed to send contract creation notification: {}", e.getMessage());
        }

        return buildDTO(contract, collaborator.getFullName());
    }

    /**
     * Get contracts by collaborator ID.
     */
    @Transactional(readOnly = true)
    public List<ContractDTO> getContractsByCollaboratorId(UUID collaboratorId) {
        CollaboratorProfileEntity collaborator = collaboratorRepository.findById(collaboratorId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Collaborator not found"));
        
        return contractRepository.findByCollaboratorIdOrderByCreatedAtDesc(collaboratorId)
                .stream()
                .map(contract -> buildDTO(contract, collaborator.getFullName()))
                .collect(Collectors.toList());
    }

    /**
     * Get contract by ID.
     */
    @Transactional(readOnly = true)
    public Optional<ContractDTO> getContractById(UUID id) {
        return contractRepository.findById(id)
                .map(contract -> {
                    String collabName = collaboratorRepository.findById(contract.getCollaboratorId())
                            .map(CollaboratorProfileEntity::getFullName)
                            .orElse(null);
                    return buildDTO(contract, collabName);
                });
    }

    /**
     * Update contract dates, region, or note.
     */
    @Transactional
    public ContractDTO updateContract(UUID id, UpdateContractDTO dto, UUID adminId, String adminRole) {
        log.info("Updating contract: id={}", id);
        
        ContractEntity contract = contractRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Contract not found"));
        
        if (contract.getStatus() == ContractStatus.TERMINATED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Cannot update terminated contract");
        }
        
        // Update fields if provided
        if (dto.getRegion() != null) {
            contract.setRegion(dto.getRegion());
        }
        if (dto.getStartDate() != null) {
            contract.setStartDate(dto.getStartDate());
        }
        if (dto.getEndDate() != null) {
            contract.setEndDate(dto.getEndDate());
        }
        if (dto.getNote() != null) {
            contract.setNote(dto.getNote());
        }
        
        // Validate dates after update
        if (contract.getEndDate().isBefore(contract.getStartDate())) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "End date must be after or equal to start date");
        }
        
        contractRepository.save(contract);
        
        String collabName = collaboratorRepository.findById(contract.getCollaboratorId())
                .map(CollaboratorProfileEntity::getFullName)
                .orElse(null);
        
        // Audit log
        writeAuditLog(adminId, adminRole, "UPDATE_CONTRACT", "CONTRACT", id,
                Map.of(
                        "startDate", contract.getStartDate().toString(),
                        "endDate", contract.getEndDate().toString(),
                        "region", contract.getRegion() != null ? contract.getRegion() : ""
                ));
        
        log.info("Contract updated: id={}", id);

        // Send notification to collaborator
        try {
            UUID userAccountId = collaboratorRepository.findById(contract.getCollaboratorId())
                    .map(c -> c.getUserAccountId()).orElse(null);
            if (userAccountId != null) {
                notificationService.send(com.example.evstation.notification.api.dto.CreateNotificationDTO.builder()
                        .recipientId(userAccountId)
                        .type(com.example.evstation.notification.domain.NotificationType.CONTRACT_UPDATED)
                        .category(com.example.evstation.notification.domain.NotificationCategory.CONTRACT)
                        .title("Contract Updated")
                        .body("Your VoltGo Collaborator contract has been updated. Period: " + contract.getStartDate() + " to " + contract.getEndDate() + ". Region: " + (contract.getRegion() != null ? contract.getRegion() : "N/A"))
                        .data(java.util.Map.of(
                                "contractId", contract.getId().toString(),
                                "startDate", contract.getStartDate().toString(),
                                "endDate", contract.getEndDate().toString(),
                                "region", contract.getRegion() != null ? contract.getRegion() : ""
                        ))
                        .referenceId(contract.getId())
                        .referenceType("CONTRACT")
                        .build());
            }
        } catch (Exception e) {
            log.warn("Failed to send contract update notification: {}", e.getMessage());
        }

        return buildDTO(contract, collabName);
    }

    /**
     * Terminate a contract.
     */
    @Transactional
    public ContractDTO terminateContract(UUID id, String reason, UUID adminId, String adminRole) {
        log.info("Terminating contract: id={}", id);
        
        ContractEntity contract = contractRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Contract not found"));
        
        if (contract.getStatus() == ContractStatus.TERMINATED) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Contract is already terminated");
        }
        
        contract.setStatus(ContractStatus.TERMINATED);
        contract.setTerminatedAt(Instant.now(clock));
        if (reason != null && !reason.isBlank()) {
            contract.setNote(contract.getNote() != null 
                    ? contract.getNote() + " | Terminated: " + reason 
                    : "Terminated: " + reason);
        }
        
        contractRepository.save(contract);
        
        String collabName = collaboratorRepository.findById(contract.getCollaboratorId())
                .map(CollaboratorProfileEntity::getFullName)
                .orElse(null);
        
        // Audit log
        writeAuditLog(adminId, adminRole, "TERMINATE_CONTRACT", "CONTRACT", id,
                Map.of(
                        "reason", reason != null ? reason : "",
                        "previousStatus", "ACTIVE",
                        "newStatus", "TERMINATED"
                ));
        
        log.info("Contract terminated: id={}", id);

        // Send notification to collaborator
        try {
            UUID userAccountId = collaboratorRepository.findById(contract.getCollaboratorId())
                    .map(c -> c.getUserAccountId()).orElse(null);
            if (userAccountId != null) {
                notificationService.send(com.example.evstation.notification.api.dto.CreateNotificationDTO.builder()
                        .recipientId(userAccountId)
                        .type(com.example.evstation.notification.domain.NotificationType.CONTRACT_TERMINATED)
                        .category(com.example.evstation.notification.domain.NotificationCategory.CONTRACT)
                        .title("Contract Terminated")
                        .body("Your VoltGo Collaborator contract has been terminated. Reason: " + (reason != null ? reason : "No reason provided"))
                        .data(java.util.Map.of(
                                "contractId", contract.getId().toString(),
                                "reason", reason != null ? reason : "",
                                "terminatedAt", contract.getTerminatedAt().toString()
                        ))
                        .referenceId(contract.getId())
                        .referenceType("CONTRACT")
                        .build());
            }
        } catch (Exception e) {
            log.warn("Failed to send contract termination notification: {}", e.getMessage());
        }

        return buildDTO(contract, collabName);
    }

    // ========== Helper Methods ==========
    
    private ContractDTO buildDTO(ContractEntity contract, String collaboratorName) {
        LocalDate today = LocalDate.now(clock);
        boolean isEffectivelyActive = contract.isEffectivelyActive(today);
        
        return ContractDTO.builder()
                .id(contract.getId().toString())
                .collaboratorId(contract.getCollaboratorId().toString())
                .collaboratorName(collaboratorName)
                .region(contract.getRegion())
                .startDate(contract.getStartDate())
                .endDate(contract.getEndDate())
                .status(contract.getStatus())
                .createdAt(contract.getCreatedAt())
                .terminatedAt(contract.getTerminatedAt())
                .note(contract.getNote())
                .isEffectivelyActive(isEffectivelyActive)
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

