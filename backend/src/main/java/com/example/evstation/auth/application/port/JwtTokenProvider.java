package com.example.evstation.auth.application.port;

import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserStatus;

import java.util.UUID;

public interface JwtTokenProvider {
    String generateToken(UUID userId, String email, Role role, UserStatus status);
    TokenClaims parseToken(String token);

    record TokenClaims(UUID userId, String email, Role role, UserStatus status) {}
}

