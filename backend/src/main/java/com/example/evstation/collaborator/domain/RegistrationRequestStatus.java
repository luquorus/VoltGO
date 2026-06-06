package com.example.evstation.collaborator.domain;

/**
 * Status of a collaborator registration request.
 */
public enum RegistrationRequestStatus {
    PENDING,    // Request is awaiting admin review
    APPROVED,   // Request approved, user account and profile created
    REJECTED    // Request rejected
}
