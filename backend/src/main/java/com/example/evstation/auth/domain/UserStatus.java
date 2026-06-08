package com.example.evstation.auth.domain;

public enum UserStatus {
    ACTIVE,
    BANNED,
    PENDING_COLLABORATOR  // Account registered but awaiting admin approval to access collaborator features
}

