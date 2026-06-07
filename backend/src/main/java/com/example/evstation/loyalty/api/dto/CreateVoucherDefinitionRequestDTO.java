package com.example.evstation.loyalty.api.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateVoucherDefinitionRequestDTO {
    @NotBlank
    private String code;
    @NotBlank
    private String name;
    private String description;
    @NotBlank
    private String voucherType;
    @NotNull @Min(1)
    private Integer pointCost;
    private Integer discountPercent;
    private Integer maxValueVnd;
    private String serviceType;
    private Instant startDate;
    private Instant endDate;
    @Builder.Default
    private Integer validityDays = 30;
}
