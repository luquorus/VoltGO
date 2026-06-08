package com.example.evstation.collaborator.application;

import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserStatus;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.collaborator.api.dto.ApproveRegistrationRequestDTO;
import com.example.evstation.collaborator.api.dto.CollaboratorRegistrationRequestDTO;
import com.example.evstation.collaborator.api.dto.RejectRegistrationRequestDTO;
import com.example.evstation.collaborator.api.dto.SubmitRegistrationRequestDTO;
import com.example.evstation.collaborator.domain.ContractStatus;
import com.example.evstation.collaborator.domain.RegistrationRequestStatus;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorRegistrationRequestEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorRegistrationRequestJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.ContractEntity;
import com.example.evstation.collaborator.infrastructure.jpa.ContractJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.common.infrastructure.email.EmailService;
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
import java.time.Period;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class CollaboratorRegistrationRequestService {

    private static final int MAX_SUBMISSIONS = 3;
    private static final int RESUBMISSION_WINDOW_DAYS = 60;

    private final CollaboratorRegistrationRequestJpaRepository requestRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final CollaboratorProfileJpaRepository collaboratorRepository;
    private final ContractJpaRepository contractRepository;
    private final AuditLogJpaRepository auditLogRepository;
    private final EmailService emailService;
    private final Clock clock;
    private final com.example.evstation.notification.application.NotificationService notificationService;

    /**
     * Submit a new registration request.
     * Email is extracted from the authenticated user's JWT token for security.
     */
    @Transactional
    public UUID submitRequest(SubmitRegistrationRequestDTO dto, String authenticatedEmail) {
        String email = authenticatedEmail.toLowerCase().trim();
        log.info("Submitting registration request for email: {}", email);

        // Verify user account exists and is in PENDING_COLLABORATOR status
        UserAccountEntity userAccount = userAccountRepository.findByEmail(email)
                .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR,
                        "No account found for this email. Please register first."));

        if (userAccount.getStatus() != UserStatus.PENDING_COLLABORATOR) {
            if (userAccount.getStatus() == UserStatus.ACTIVE) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                        "This account is already active. You may already be registered as a collaborator.");
            }
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Account is not in a valid state for registration. Status: " + userAccount.getStatus());
        }

        // Check if a PENDING request already exists for this email
        List<CollaboratorRegistrationRequestEntity> pending = requestRepository
                .findByEmailAndStatusIn(email, List.of(
                        RegistrationRequestStatus.PENDING,
                        RegistrationRequestStatus.APPROVED));

        if (!pending.isEmpty()) {
            CollaboratorRegistrationRequestEntity existing = pending.get(0);
            if (existing.getStatus() == RegistrationRequestStatus.PENDING) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                        "A registration request is already pending for this email. Please wait for admin review.");
            } else if (existing.getStatus() == RegistrationRequestStatus.APPROVED) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                        "An account with this email already exists and is active.");
            }
        }

        // Check resubmission limit
        if (!canResubmit(email)) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Maximum resubmission limit reached. You can only submit " + MAX_SUBMISSIONS +
                    " requests within " + RESUBMISSION_WINDOW_DAYS + " days");
        }

        // Validate age (must be 18+)
        validateAge(dto.getDateOfBirth());

        // Parse contract agreed timestamp
        Instant contractAgreedAt;
        if (dto.getContractAgreedAt() != null && !dto.getContractAgreedAt().isEmpty()) {
            contractAgreedAt = Instant.parse(dto.getContractAgreedAt());
        } else {
            contractAgreedAt = Instant.now(clock);
        }

        // Count existing requests for this email in the window
        Instant windowStart = Instant.now(clock).minusSeconds((long) RESUBMISSION_WINDOW_DAYS * 24 * 60 * 60);
        long existingCount = requestRepository.countByEmailAndCreatedAtAfter(email, windowStart);

        // Create the request
        CollaboratorRegistrationRequestEntity request = CollaboratorRegistrationRequestEntity.builder()
                .id(UUID.randomUUID())
                .email(email)
                .fullName(dto.getFullName())
                .phone(dto.getPhone())
                .dateOfBirth(dto.getDateOfBirth())
                .address(dto.getAddress())
                .idCardNumber(dto.getIdCardNumber())
                .bankAccountNumber(dto.getBankAccountNumber())
                .bankName(dto.getBankName())
                .contractAgreedAt(contractAgreedAt)
                .status(RegistrationRequestStatus.PENDING)
                .submissionCount((int) (existingCount + 1))
                .build();

        requestRepository.save(request);

        log.info("Registration request submitted: id={}, email={}", request.getId(), email);
        return request.getId();
    }

    /**
     * Check if an email can resubmit (under the limit within the time window).
     */
    public boolean canResubmit(String email) {
        Instant windowStart = Instant.now(clock).minusSeconds((long) RESUBMISSION_WINDOW_DAYS * 24 * 60 * 60);
        long count = requestRepository.countByEmailAndCreatedAtAfter(email.toLowerCase().trim(), windowStart);
        return count < MAX_SUBMISSIONS;
    }

    /**
     * Get registration requests with optional status filter.
     */
    @Transactional(readOnly = true)
    public Page<CollaboratorRegistrationRequestDTO> getRequests(String status, Pageable pageable) {
        Page<CollaboratorRegistrationRequestEntity> page;
        
        if (status != null && !status.isEmpty()) {
            try {
                RegistrationRequestStatus requestStatus = RegistrationRequestStatus.valueOf(status.toUpperCase());
                page = requestRepository.findByStatusOrderByCreatedAtDesc(requestStatus, pageable);
            } catch (IllegalArgumentException e) {
                page = requestRepository.findByStatusNotOrderByCreatedAtDesc(RegistrationRequestStatus.APPROVED, pageable);
            }
        } else {
            // Default "All" view excludes APPROVED requests (they have moved to contracts)
            page = requestRepository.findByStatusNotOrderByCreatedAtDesc(RegistrationRequestStatus.APPROVED, pageable);
        }

        return page.map(this::buildDTO);
    }

    /**
     * Get a single registration request by ID.
     */
    @Transactional(readOnly = true)
    public CollaboratorRegistrationRequestDTO getRequest(UUID id) {
        return requestRepository.findById(id)
                .map(this::buildDTO)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Registration request not found"));
    }

    /**
     * Approve a registration request.
     * Updates existing UserAccount (created via /auth/register), creates CollaboratorProfile and Contract.
     * Sends email notification.
     */
    @Transactional
    public CollaboratorRegistrationRequestDTO approveRequest(UUID id, ApproveRegistrationRequestDTO dto, UUID adminId) {
        log.info("Approving registration request: id={}", id);

        CollaboratorRegistrationRequestEntity request = requestRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Registration request not found"));

        if (request.getStatus() != RegistrationRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Request is not pending. Current status: " + request.getStatus());
        }

        // Find existing user account (created via /auth/register)
        UserAccountEntity userAccount = userAccountRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new BusinessException(ErrorCode.INTERNAL_ERROR,
                        "User account not found for approved registration"));

        // Update user account status and name
        userAccount.setStatus(UserStatus.ACTIVE);
        if (request.getFullName() != null && !request.getFullName().isEmpty()) {
            userAccount.setName(request.getFullName());
        }
        if (request.getPhone() != null && !request.getPhone().isEmpty()) {
            userAccount.setPhone(request.getPhone());
        }
        userAccountRepository.save(userAccount);

        // Create collaborator profile
        CollaboratorProfileEntity collaborator = CollaboratorProfileEntity.builder()
                .userAccountId(userAccount.getId())
                .fullName(request.getFullName())
                .phone(request.getPhone())
                .createdAt(Instant.now(clock))
                .build();
        collaboratorRepository.save(collaborator);

        // Create contract with region from approval
        LocalDate startDate = LocalDate.now(clock);
        LocalDate endDate = startDate.plusYears(1);
        
        ContractEntity contract = ContractEntity.builder()
                .collaboratorId(collaborator.getId())
                .region(dto.getRegion())
                .startDate(startDate)
                .endDate(endDate)
                .status(ContractStatus.ACTIVE)
                .note(dto.getNote())
                .createdAt(Instant.now(clock))
                .build();
        contractRepository.save(contract);

        // Update request status
        request.setStatus(RegistrationRequestStatus.APPROVED);
        request.setReviewedBy(adminId);
        request.setReviewedAt(Instant.now(clock));
        requestRepository.save(request);

        // Write audit log
        writeAuditLog(adminId, "ADMIN", "APPROVE_REGISTRATION_REQUEST", "COLLABORATOR_REGISTRATION_REQUEST", id,
                Map.of(
                        "email", request.getEmail(),
                        "fullName", request.getFullName(),
                        "region", dto.getRegion(),
                        "userAccountId", userAccount.getId().toString(),
                        "collaboratorId", collaborator.getId().toString(),
                        "contractId", contract.getId().toString()
                ));

        // Send approval email
        String emailSubject = "VoltGo - Registration Approved";
        String emailBody = String.format(
                "Dear %s,\n\n" +
                "Your registration request has been approved!\n\n" +
                "You can now login to VoltGo Collaborator app with your registered email.\n\n" +
                "Region: %s\n" +
                "Note: %s\n\n" +
                "Best regards,\n" +
                "VoltGo Team",
                request.getFullName(),
                dto.getRegion(),
                dto.getNote() != null ? dto.getNote() : "N/A"
        );
        emailService.sendEmail(request.getEmail(), emailSubject, emailBody);

        // Send push + in-app notification
        try {
            notificationService.send(com.example.evstation.notification.api.dto.CreateNotificationDTO.builder()
                    .recipientId(userAccount.getId())
                    .type(com.example.evstation.notification.domain.NotificationType.CONTRACT_APPROVED)
                    .category(com.example.evstation.notification.domain.NotificationCategory.CONTRACT)
                    .title("Registration Approved!")
                    .body("Congratulations! Your VoltGo Collaborator contract has been approved. Region: " + (dto.getRegion() != null ? dto.getRegion() : "N/A"))
                    .data(java.util.Map.of(
                            "contractId", contract.getId().toString(),
                            "region", dto.getRegion() != null ? dto.getRegion() : "",
                            "startDate", startDate.toString(),
                            "endDate", endDate.toString()
                    ))
                    .referenceId(contract.getId())
                    .referenceType("CONTRACT")
                    .build());
        } catch (Exception e) {
            log.warn("Failed to send approval notification: {}", e.getMessage());
        }

        log.info("Registration request approved: id={}, email={}, userAccountId={}", 
                id, request.getEmail(), userAccount.getId());

        return buildDTO(request);
    }

    /**
     * Reject a registration request.
     */
    @Transactional
    public CollaboratorRegistrationRequestDTO rejectRequest(UUID id, RejectRegistrationRequestDTO dto, UUID adminId) {
        log.info("Rejecting registration request: id={}", id);

        CollaboratorRegistrationRequestEntity request = requestRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Registration request not found"));

        if (request.getStatus() != RegistrationRequestStatus.PENDING) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "Request is not pending. Current status: " + request.getStatus());
        }

        // Update request status
        request.setStatus(RegistrationRequestStatus.REJECTED);
        request.setRejectionReason(dto.getReason());
        request.setReviewedBy(adminId);
        request.setReviewedAt(Instant.now(clock));
        requestRepository.save(request);

        // Write audit log
        writeAuditLog(adminId, "ADMIN", "REJECT_REGISTRATION_REQUEST", "COLLABORATOR_REGISTRATION_REQUEST", id,
                Map.of(
                        "email", request.getEmail(),
                        "fullName", request.getFullName(),
                        "reason", dto.getReason()
                ));

        // Send rejection email
        String emailSubject = "VoltGo - Registration Not Approved";
        String emailBody = String.format(
                "Dear %s,\n\n" +
                "Thank you for your interest in becoming a VoltGo Collaborator.\n\n" +
                "Unfortunately, your registration request was not approved at this time.\n\n" +
                "Reason: %s\n\n" +
                "If you believe this was a mistake or would like to try again, " +
                "please submit a new registration request.\n\n" +
                "Best regards,\n" +
                "VoltGo Team",
                request.getFullName(),
                dto.getReason()
        );
        emailService.sendEmail(request.getEmail(), emailSubject, emailBody);

        // Send in-app notification + push + email (via NotificationService)
        try {
            UserAccountEntity userAccount = userAccountRepository.findByEmail(request.getEmail()).orElse(null);
            if (userAccount != null) {
                notificationService.send(com.example.evstation.notification.api.dto.CreateNotificationDTO.builder()
                        .recipientId(userAccount.getId())
                        .type(com.example.evstation.notification.domain.NotificationType.SYSTEM_ANNOUNCEMENT)
                        .category(com.example.evstation.notification.domain.NotificationCategory.ALL)
                        .title("Registration Not Approved")
                        .body("Your VoltGo Collaborator registration request was not approved. Reason: " + (dto.getReason() != null ? dto.getReason() : "No reason provided"))
                        .data(java.util.Map.of(
                                "requestId", request.getId().toString(),
                                "reason", dto.getReason() != null ? dto.getReason() : ""
                        ))
                        .referenceId(request.getId())
                        .referenceType("COLLABORATOR_REGISTRATION_REQUEST")
                        .build());
            }
        } catch (Exception e) {
            log.warn("Failed to send rejection notification: {}", e.getMessage());
        }

        log.info("Registration request rejected: id={}, email={}", id, request.getEmail());

        return buildDTO(request);
    }

    /**
     * Get count of pending requests.
     */
    @Transactional(readOnly = true)
    public long countPendingRequests() {
        return requestRepository.countByStatus(RegistrationRequestStatus.PENDING);
    }

    /**
     * Delete a registration request by ID.
     */
    @Transactional
    public void deleteRequest(UUID id) {
        log.info("Deleting registration request: id={}", id);

        CollaboratorRegistrationRequestEntity request = requestRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Registration request not found"));

        requestRepository.delete(request);
        log.info("Deleted registration request: id={}", id);
    }

    // ========== Helper Methods ==========

    private void validateAge(LocalDate dateOfBirth) {
        if (dateOfBirth == null) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Date of birth is required");
        }
        
        LocalDate today = LocalDate.now(clock);
        int age = Period.between(dateOfBirth, today).getYears();
        
        if (age < 18) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, 
                    "You must be at least 18 years old to register");
        }
    }

    private CollaboratorRegistrationRequestDTO buildDTO(CollaboratorRegistrationRequestEntity entity) {
        return CollaboratorRegistrationRequestDTO.builder()
                .id(entity.getId())
                .email(entity.getEmail())
                .fullName(entity.getFullName())
                .phone(entity.getPhone())
                .dateOfBirth(entity.getDateOfBirth())
                .address(entity.getAddress())
                .idCardNumber(entity.getIdCardNumber())
                .bankAccountNumber(entity.getBankAccountNumber())
                .bankName(entity.getBankName())
                .contractAgreedAt(entity.getContractAgreedAt())
                .status(entity.getStatus())
                .rejectionReason(entity.getRejectionReason())
                .submissionCount(entity.getSubmissionCount())
                .canResubmit(canResubmit(entity.getEmail()))
                .reviewedBy(entity.getReviewedBy())
                .reviewedAt(entity.getReviewedAt())
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt())
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
