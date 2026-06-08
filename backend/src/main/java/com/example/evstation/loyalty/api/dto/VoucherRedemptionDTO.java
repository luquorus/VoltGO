package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.VoucherDefinitionEntity;
import com.example.evstation.loyalty.infrastructure.jpa.VoucherRedemptionEntity;
import lombok.*;

import java.time.Instant;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VoucherRedemptionDTO {
    private String id;
    private String userId;
    private String voucherDefinitionId;
    private VoucherDefinitionDTO definition;
    private String voucherCode;
    private String status;
    private Integer pointsSpent;
    private Instant redeemedAt;
    private Instant expiresAt;
    private Instant usedAt;
    private String bookingId;
    private String serviceType;
    private Map<String, Object> metadata;

    public static VoucherRedemptionDTO fromEntity(VoucherRedemptionEntity entity, VoucherDefinitionEntity def, Long redemptionCount) {
        VoucherDefinitionDTO defDto = def != null ? VoucherDefinitionDTO.fromEntity(def, redemptionCount) : null;
        return VoucherRedemptionDTO.builder()
                .id(entity.getId().toString())
                .userId(entity.getUserId().toString())
                .voucherDefinitionId(entity.getVoucherDefinitionId().toString())
                .definition(defDto)
                .voucherCode(entity.getVoucherCode())
                .status(entity.getStatus().name())
                .pointsSpent(entity.getPointsSpent())
                .redeemedAt(entity.getRedeemedAt())
                .expiresAt(entity.getExpiresAt())
                .usedAt(entity.getUsedAt())
                .bookingId(entity.getBookingId() != null ? entity.getBookingId().toString() : null)
                .serviceType(entity.getServiceType())
                .metadata(entity.getMetadata())
                .build();
    }
}
