package com.example.evstation.loyalty.api.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApplyVoucherRequestDTO {
    @NotBlank
    private String bookingId;
}
