package com.example.evstation.auth.infrastructure.security;

import com.example.evstation.auth.application.port.JwtTokenProvider;
import com.example.evstation.auth.domain.Role;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtTokenProviderImpl implements JwtTokenProvider {
    private final SecretKey secretKey;
    private static final long EXPIRATION_HOURS = 24;

    public JwtTokenProviderImpl(@Value("${jwt.secret:voltgo-secret-key-change-in-production-min-256-bits}") String secret) {
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    @Override
    public String generateToken(UUID userId, String email, Role role) {
        Instant now = Instant.now();
        Instant expiry = now.plus(EXPIRATION_HOURS, ChronoUnit.HOURS);

        return Jwts.builder()
                .subject(userId.toString())
                .claim("email", email)
                .claim("role", role.name())
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(secretKey)
                .compact();
    }

    @Override
    public TokenClaims parseToken(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(secretKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            UUID userId = UUID.fromString(claims.getSubject());
            String email = claims.get("email", String.class);
            Role role = Role.valueOf(claims.get("role", String.class));

            return new TokenClaims(userId, email, role);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid token", e);
        }
    }
}

