package com.example.evstation.batteryswap.domain;

/**
 * Status for battery swap change requests.
 */
public enum ChangeRequestStatus {
    DRAFT,
    PENDING,
    APPROVED,
    REJECTED,
    PUBLISHED,
    SUBMITTED,
    IN_REVIEW
}
