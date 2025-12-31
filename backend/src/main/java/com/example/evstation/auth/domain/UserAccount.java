package com.example.evstation.auth.domain;

import java.time.Instant;
import java.util.UUID;

public class UserAccount {
    private UUID id;
    private String email;
    private String passwordHash;
    private Role role;
    private UserStatus status;
    private Instant createdAt;

    // Constructor for new account
    public UserAccount(String email, String passwordHash, Role role) {
        this.id = UUID.randomUUID();
        this.email = email;
        this.passwordHash = passwordHash;
        this.role = role;
        this.status = UserStatus.ACTIVE;
        this.createdAt = Instant.now();
    }

    // Constructor for existing account
    public UserAccount(UUID id, String email, String passwordHash, Role role, UserStatus status, Instant createdAt) {
        this.id = id;
        this.email = email;
        this.passwordHash = passwordHash;
        this.role = role;
        this.status = status;
        this.createdAt = createdAt;
    }

    public boolean isActive() {
        return status == UserStatus.ACTIVE;
    }

    public boolean canAccessEvApi() {
        return isActive() && (role == Role.EV_USER || role == Role.PROVIDER);
    }

    public boolean canAccessCollabApi() {
        return isActive() && role == Role.COLLABORATOR;
    }

    public boolean canAccessAdminApi() {
        return isActive() && role == Role.ADMIN;
    }

    // Getters
    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public Role getRole() {
        return role;
    }

    public UserStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}

