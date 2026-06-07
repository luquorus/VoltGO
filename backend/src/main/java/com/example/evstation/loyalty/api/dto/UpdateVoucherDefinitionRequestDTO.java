package com.example.evstation.loyalty.api.dto;

import jakarta.validation.constraints.Min;
import lombok.*;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateVoucherDefinitionRequestDTO {
    private String name;
    private String description;
    private String voucherType;
    @Min(1)
    private Integer pointCost;
    private Integer discountPercent;
    private Integer maxValueVnd;
    private String serviceType;
    private Instant startDate;
    private Instant endDate;
    @Min(1)
    private Integer validityDays;
}
