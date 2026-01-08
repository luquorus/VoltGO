package com.example.evstation.verification.domain;

/**
 * Status of a verification task.
 */
public enum VerificationTaskStatus {
    OPEN,       // Task created, not assigned
    ASSIGNED,   // Assigned to collaborator
    CHECKED_IN, // Collaborator checked in at location
    SUBMITTED,  // Evidence submitted
    REVIEWED    // Admin reviewed
}

