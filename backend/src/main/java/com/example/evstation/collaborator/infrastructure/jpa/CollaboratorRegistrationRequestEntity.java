package com.example.evstation.collaborator.infrastructure.jpa;

import com.example.evstation.collaborator.domain.RegistrationRequestStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "collaborator_registration_request", indexes = {
    @Index(name = "idx_reg_req_email", columnList = "email"),
    @Index(name = "idx_reg_req_status", columnList = "status"),
    @Index(name = "idx_reg_req_created_at", columnList = "created_at")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CollaboratorRegistrationRequestEntity {

    @Id
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(nullable = false)
    private String email;

    // Note: password is NOT stored here. It was already hashed and stored in
    // UserAccount at registration time. The registration request only collects
    // profile/banking information for admin review.

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(length = 20)
    private String phone;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Column(name = "id_card_number", length = 20)
    private String idCardNumber;

    @Column(name = "bank_account_number", length = 50)
    private String bankAccountNumber;

    @Column(name = "bank_name", length = 100)
    private String bankName;

    @Column(name = "referral_code", length = 50)
    private String referralCode;

    @Column(name = "contract_agreed_at")
    private Instant contractAgreedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RegistrationRequestStatus status;

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;

    @Column(name = "submission_count", nullable = false)
    @Builder.Default
    private int submissionCount = 1;

    @Column(name = "reviewed_by", columnDefinition = "UUID")
    private UUID reviewedBy;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (status == null) {
            status = RegistrationRequestStatus.PENDING;
        }
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (updatedAt == null) {
            updatedAt = Instant.now();
        }
    }
}
