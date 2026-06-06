package com.example.evstation.collaborator.api.dto;

import com.example.evstation.collaborator.domain.RegistrationRequestStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CollaboratorRegistrationRequestDTO {

    private UUID id;
    private String email;
    private String fullName;
    private String phone;
    private LocalDate dateOfBirth;
    private String address;
    private String idCardNumber;
    private String bankAccountNumber;
    private String bankName;
    private String referralCode;
    private Instant contractAgreedAt;
    private RegistrationRequestStatus status;
    private String rejectionReason;
    private int submissionCount;
    private boolean canResubmit;
    private UUID reviewedBy;
    private Instant reviewedAt;
    private Instant createdAt;
    private Instant updatedAt;

    public int getAge() {
        if (dateOfBirth == null) {
            return 0;
        }
        return Period.between(dateOfBirth, LocalDate.now()).getYears();
    }
}
