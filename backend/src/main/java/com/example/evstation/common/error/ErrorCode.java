package com.example.evstation.common.error;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {
    // Generic errors
    INTERNAL_ERROR("EVS-0001", "Internal server error"),
    VALIDATION_ERROR("EVS-0002", "Validation error"),
    NOT_FOUND("EVS-0003", "Resource not found"),
    UNAUTHORIZED("EVS-0004", "Unauthorized"),
    FORBIDDEN("EVS-0005", "Forbidden"),
    INVALID_INPUT("EVS-0006", "Invalid input"),
    INVALID_STATE("EVS-0007", "Invalid state"),
    
    // Booking errors
    SLOT_UNAVAILABLE("EVS-0008", "Slot unavailable"),
    CHARGER_UNIT_NOT_FOUND("EVS-0009", "Charger unit not found"),
    CHARGER_UNIT_INACTIVE("EVS-0010", "Charger unit is not active"),
    INVALID_TIME_RANGE("EVS-0011", "Invalid time range"),
    ;

    private final String code;
    private final String message;
}

