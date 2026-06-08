package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.VoucherDefinitionEntity;
import lombok.*;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VoucherDefinitionDTO {
    private String id;
    private String code;
    private String name;
    private String description;
    private String voucherType;
    private Integer pointCost;
    private Integer discountPercent;
    private Integer maxValueVnd;
    private String serviceType;
    private String status;
    private Instant startDate;
    private Instant endDate;
    private Integer validityDays;
    private Long redemptionCount;
    private Instant createdAt;

    public static VoucherDefinitionDTO fromEntity(VoucherDefinitionEntity entity, Long redemptionCount) {
        return VoucherDefinitionDTO.builder()
                .id(entity.getId().toString())
                .code(entity.getCode())
                .name(entity.getName())
                .description(entity.getDescription())
                .voucherType(entity.getVoucherType().name())
                .pointCost(entity.getPointCost())
                .discountPercent(entity.getDiscountPercent())
                .maxValueVnd(entity.getMaxValueVnd())
                .serviceType(entity.getServiceType())
                .status(entity.getStatus().name())
                .startDate(entity.getStartDate())
                .endDate(entity.getEndDate())
                .validityDays(entity.getValidityDays())
                .redemptionCount(redemptionCount)
                .createdAt(entity.getCreatedAt())
                .build();
    }
}
