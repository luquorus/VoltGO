package com.example.evstation.loyalty.api.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class SubmitRatingRequestDTO {
    @NotNull private String stationId;
    private String eligibilityId;
    @NotNull @Min(1) @Max(5) private Integer rating;
    private String comment;
}
