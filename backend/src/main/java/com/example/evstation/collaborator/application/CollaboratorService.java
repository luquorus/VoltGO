package com.example.evstation.collaborator.application;

import com.example.evstation.auth.application.port.PasswordEncoder;
import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserStatus;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.collaborator.api.dto.CollaboratorLocationDTO;
import com.example.evstation.collaborator.api.dto.CollaboratorProfileDTO;
import com.example.evstation.collaborator.api.dto.CreateCollaboratorAccountDTO;
import com.example.evstation.collaborator.api.dto.CreateCollaboratorDTO;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.ContractJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class CollaboratorService {
    
    private final CollaboratorProfileJpaRepository collaboratorRepository;
    private final ContractJpaRepository contractRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;

    /**
     * Create a collaborator profile for a user account with role COLLABORATOR.
     */
    @Transactional
    public CollaboratorProfileDTO createCollaborator(CreateCollaboratorDTO dto, UUID adminId, String adminRole) {
        log.info("Creating collaborator profile: userAccountId={}", dto.getUserAccountId());
        
        // Verify user account exists and has COLLABORATOR role
        UserAccountEntity userAccount = userAccountRepository.findById(dto.getUserAccountId())
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "User account not found"));
        
        if (userAccount.getRole() != Role.COLLABORATOR) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "User account must have COLLABORATOR role. Current role: " + userAccount.getRole());
        }
        
        // Check if profile already exists
        if (collaboratorRepository.existsByUserAccountId(dto.getUserAccountId())) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Collaborator profile already exists for this user account");
        }
        
        // Create profile
        CollaboratorProfileEntity profile = CollaboratorProfileEntity.builder()
                .userAccountId(dto.getUserAccountId())
                .fullName(dto.getFullName())
                .phone(dto.getPhone())
                .createdAt(Instant.now(clock))
                .build();
        
        collaboratorRepository.save(profile);
        
        // Audit log
        writeAuditLog(adminId, adminRole, "CREATE_COLLABORATOR_PROFILE", "COLLABORATOR_PROFILE", profile.getId(),
                Map.of(
                        "userAccountId", dto.getUserAccountId().toString(),
                        "email", userAccount.getEmail(),
                        "fullName", dto.getFullName() != null ? dto.getFullName() : ""
                ));
        
        log.info("Collaborator profile created: id={}", profile.getId());
        return buildDTO(profile, userAccount.getEmail(), false);
    }

    /**
     * Get all collaborator profiles with pagination.
     */
    @Transactional(readOnly = true)
    public Page<CollaboratorProfileDTO> getAllCollaborators(Pageable pageable) {
        LocalDate today = LocalDate.now(clock);
        
        return collaboratorRepository.findAllByOrderByCreatedAtDesc(pageable)
                .map(profile -> {
                    String email = userAccountRepository.findById(profile.getUserAccountId())
                            .map(UserAccountEntity::getEmail)
                            .orElse(null);
                    boolean hasActive = contractRepository.hasEffectiveActiveContract(profile.getId(), today);
                    return buildDTO(profile, email, hasActive);
                });
    }

    /**
     * Get collaborator profile by ID.
     */
    @Transactional(readOnly = true)
    public Optional<CollaboratorProfileDTO> getCollaboratorById(UUID id) {
        LocalDate today = LocalDate.now(clock);
        
        return collaboratorRepository.findById(id)
                .map(profile -> {
                    String email = userAccountRepository.findById(profile.getUserAccountId())
                            .map(UserAccountEntity::getEmail)
                            .orElse(null);
                    boolean hasActive = contractRepository.hasEffectiveActiveContract(profile.getId(), today);
                    return buildDTO(profile, email, hasActive);
                });
    }

    /**
     * Get collaborator profile by user account ID.
     */
    @Transactional(readOnly = true)
    public Optional<CollaboratorProfileDTO> getCollaboratorByUserAccountId(UUID userAccountId) {
        LocalDate today = LocalDate.now(clock);

        return collaboratorRepository.findByUserAccountId(userAccountId)
                .map(profile -> {
                    String email = userAccountRepository.findById(profile.getUserAccountId())
                            .map(UserAccountEntity::getEmail)
                            .orElse(null);
                    boolean hasActive = contractRepository.hasEffectiveActiveContract(profile.getId(), today);
                    return buildDTO(profile, email, hasActive);
                });
    }

    /**
     * Create a new user account and collaborator profile in one step.
     */
    @Transactional
    public CollaboratorProfileDTO createCollaboratorWithAccount(CreateCollaboratorAccountDTO dto, UUID adminId, String adminRole) {
        log.info("Creating collaborator account: email={}", dto.getEmail());

        // Check if email already exists
        if (userAccountRepository.existsByEmail(dto.getEmail())) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Email already exists");
        }

        // Create user account
        String passwordHash = passwordEncoder.encode(dto.getPassword());
        UserAccountEntity userAccount = UserAccountEntity.builder()
                .id(UUID.randomUUID())
                .email(dto.getEmail())
                .name(dto.getFullName())
                .passwordHash(passwordHash)
                .role(Role.COLLABORATOR)
                .status(UserStatus.ACTIVE)
                .createdAt(Instant.now(clock))
                .build();

        userAccountRepository.save(userAccount);

        // Create collaborator profile
        CollaboratorProfileEntity profile = CollaboratorProfileEntity.builder()
                .userAccountId(userAccount.getId())
                .fullName(dto.getFullName())
                .createdAt(Instant.now(clock))
                .build();

        collaboratorRepository.save(profile);

        // Audit log
        writeAuditLog(adminId, adminRole, "CREATE_COLLABORATOR_WITH_ACCOUNT", "COLLABORATOR_PROFILE", profile.getId(),
                Map.of(
                        "userAccountId", userAccount.getId().toString(),
                        "email", dto.getEmail(),
                        "fullName", dto.getFullName()
                ));

        log.info("Collaborator account created: id={}, userAccountId={}", profile.getId(), userAccount.getId());
        return buildDTO(profile, userAccount.getEmail(), false);
    }

    /**
     * Delete a collaborator profile and its associated user account.
     */
    @Transactional
    public void deleteCollaborator(UUID collaboratorId, UUID adminId, String adminRole) {
        log.info("Deleting collaborator: id={}", collaboratorId);

        CollaboratorProfileEntity profile = collaboratorRepository.findById(collaboratorId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Collaborator profile not found"));

        UUID userAccountId = profile.getUserAccountId();

        // Delete collaborator profile first (FK constraint)
        collaboratorRepository.delete(profile);

        // Delete user account
        userAccountRepository.deleteById(userAccountId);

        // Audit log
        writeAuditLog(adminId, adminRole, "DELETE_COLLABORATOR", "COLLABORATOR_PROFILE", collaboratorId,
                Map.of(
                        "deletedUserAccountId", userAccountId.toString(),
                        "deletedProfileId", collaboratorId.toString()
                ));

        log.info("Collaborator deleted: id={}, userAccountId={}", collaboratorId, userAccountId);
    }

    // ========== Helper Methods ==========
    
    private CollaboratorProfileDTO buildDTO(CollaboratorProfileEntity profile, String email, boolean hasActiveContract) {
        CollaboratorLocationDTO locationDTO = null;
        if (profile.getCurrentLocation() != null) {
            locationDTO = CollaboratorLocationDTO.builder()
                    .lat(profile.getLatitude())
                    .lng(profile.getLongitude())
                    .updatedAt(profile.getLocationUpdatedAt())
                    .source(profile.getLocationSource() != null ? profile.getLocationSource().name() : null)
                    .build();
        }
        
        return CollaboratorProfileDTO.builder()
                .id(profile.getId().toString())
                .userAccountId(profile.getUserAccountId().toString())
                .email(email)
                .fullName(profile.getFullName())
                .phone(profile.getPhone())
                .createdAt(profile.getCreatedAt())
                .hasActiveContract(hasActiveContract)
                .location(locationDTO)
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

