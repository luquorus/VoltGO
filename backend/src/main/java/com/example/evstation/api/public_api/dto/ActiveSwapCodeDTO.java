package com.example.evstation.api.public_api.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
public class ActiveSwapCodeDTO {
    private String swapCode;
    private Instant deadlineAt;
    private String reservationId;
}
