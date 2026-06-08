package com.example.evstation.collaborator.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SubmitRegistrationRequestDTO {

    // Note: email is NOT in the request body — it is extracted from the authenticated JWT token

    @NotBlank(message = "Full name is required")
    private String fullName;

    @NotBlank(message = "Phone is required")
    private String phone;

    @NotNull(message = "Date of birth is required")
    @Past(message = "Date of birth must be in the past")
    private LocalDate dateOfBirth;

    @NotBlank(message = "Address is required")
    private String address;

    @NotBlank(message = "ID card number is required")
    private String idCardNumber;

    @NotBlank(message = "Bank account number is required")
    private String bankAccountNumber;

    @NotBlank(message = "Bank name is required")
    private String bankName;

    private String contractAgreedAt;  // optional — backend generates if not provided
}
