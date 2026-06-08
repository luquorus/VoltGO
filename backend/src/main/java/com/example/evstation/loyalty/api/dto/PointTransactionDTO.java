package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.LoyaltyPointTransactionEntity;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
public class PointTransactionDTO {
    private String id;
    private String type;
    private String source;
    private String sourceId;
    private Integer points;
    private Integer balanceAfter;
    private String description;
    private Instant createdAt;

    public static PointTransactionDTO fromEntity(LoyaltyPointTransactionEntity e) {
        return PointTransactionDTO.builder()
                .id(e.getId().toString())
                .type(e.getType().name())
                .source(e.getSource().name())
                .sourceId(e.getSourceId() != null ? e.getSourceId().toString() : null)
                .points(e.getPoints())
                .balanceAfter(e.getBalanceAfter())
                .description(e.getDescription())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
