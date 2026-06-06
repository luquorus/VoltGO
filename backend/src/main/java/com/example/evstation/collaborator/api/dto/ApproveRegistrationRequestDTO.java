package com.example.evstation.collaborator.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApproveRegistrationRequestDTO {

    @NotBlank(message = "Region is required")
    private String region;

    private String note;
}
