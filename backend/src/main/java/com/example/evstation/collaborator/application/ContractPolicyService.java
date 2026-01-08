package com.example.evstation.collaborator.application;

import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.ContractJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Policy service for checking contract-related business rules.
 * Used by verification evidence submission to ensure collaborator has active contract.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ContractPolicyService {
    
    private final CollaboratorProfileJpaRepository collaboratorRepository;
    private final ContractJpaRepository contractRepository;
    private final Clock clock;

    /**
     * Require that the collaborator (by user account ID) has an active contract.
     * Throws Forbidden (403) if no active contract exists.
     * 
     * @param collaboratorUserId The user account ID of the collaborator
     * @throws BusinessException with FORBIDDEN if no active contract
     */
    @Transactional(readOnly = true)
    public void requireActiveContract(UUID collaboratorUserId) {
        log.debug("Checking active contract for collaborator user: {}", collaboratorUserId);
        
        LocalDate today = LocalDate.now(clock);
        
        // Find collaborator profile
        CollaboratorProfileEntity profile = collaboratorRepository.findByUserAccountId(collaboratorUserId)
                .orElseThrow(() -> {
                    log.warn("Collaborator profile not found for user: {}", collaboratorUserId);
                    return new BusinessException(ErrorCode.FORBIDDEN, 
                            "Collaborator profile not found. Please contact admin.");
                });
        
        // Check for active contract
        boolean hasActiveContract = contractRepository.hasEffectiveActiveContract(profile.getId(), today);
        
        if (!hasActiveContract) {
            log.warn("No active contract for collaborator: userId={}, profileId={}", 
                    collaboratorUserId, profile.getId());
            throw new BusinessException(ErrorCode.FORBIDDEN, 
                    "No active contract. You must have an active contract to submit verification evidence.");
        }
        
        log.debug("Active contract verified for collaborator: userId={}", collaboratorUserId);
    }

    /**
     * Check if collaborator has an active contract (non-throwing version).
     * 
     * @param collaboratorUserId The user account ID of the collaborator
     * @return true if has active contract, false otherwise
     */
    @Transactional(readOnly = true)
    public boolean hasActiveContract(UUID collaboratorUserId) {
        LocalDate today = LocalDate.now(clock);
        
        return collaboratorRepository.findByUserAccountId(collaboratorUserId)
                .map(profile -> contractRepository.hasEffectiveActiveContract(profile.getId(), today))
                .orElse(false);
    }
}

