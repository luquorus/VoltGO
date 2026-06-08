package com.example.evstation.loyalty.api.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AdjustPointsRequestDTO {
    @NotNull private Integer delta;
    @NotNull private String reason;
}
