package com.example.evstation.loyalty.api.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class LoyaltyDashboardDTO {
    private Integer totalPointsIssued;
    private Integer activeUsers;
    private Integer totalRatings;
}
