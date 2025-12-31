package com.example.evstation.auth.infrastructure.security;

import com.example.evstation.auth.application.port.JwtTokenProvider;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * JWT Authentication Filter
 * 
 * Maps JWT claim "role" to Spring Security GrantedAuthority:
 * - EV_USER -> ROLE_EV_USER
 * - PROVIDER -> ROLE_PROVIDER
 * - COLLABORATOR -> ROLE_COLLABORATOR
 * - ADMIN -> ROLE_ADMIN
 * 
 * This allows @PreAuthorize("hasRole('EV_USER')") to work correctly.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtTokenProvider jwtTokenProvider;
    private static final String AUTH_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        String requestUri = request.getRequestURI();
        String authHeader = request.getHeader(AUTH_HEADER);

        // Log all requests to /api/** for debugging
        if (requestUri.startsWith("/api/")) {
            log.info("[JWT] Processing request: {} {} hasAuth={}", 
                    request.getMethod(), requestUri, authHeader != null);
        }

        if (authHeader != null && authHeader.startsWith(BEARER_PREFIX)) {
            String token = authHeader.substring(BEARER_PREFIX.length());
            try {
                JwtTokenProvider.TokenClaims claims = jwtTokenProvider.parseToken(token);
                
                // Map JWT role claim to Spring Security authority
                // hasRole("EV_USER") checks for "ROLE_EV_USER" authority
                String roleName = claims.role().name();
                SimpleGrantedAuthority authority = new SimpleGrantedAuthority("ROLE_" + roleName);
                
                UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                        claims.userId(),
                        null,
                        List.of(authority)
                );
                authentication.setDetails(claims);

                SecurityContextHolder.getContext().setAuthentication(authentication);
                
                // INFO level logging for debugging
                log.info("[JWT] Auth SUCCESS: uri={}, userId={}, role={}, authority={}", 
                        requestUri, claims.userId(), claims.role(), authority.getAuthority());
            } catch (Exception e) {
                log.warn("[JWT] Auth FAILED: uri={}, error={}", requestUri, e.getMessage(), e);
                // Invalid token - continue without authentication
                // SecurityFilterChain will handle 403 if endpoint requires authentication
            }
        } else if (requestUri.startsWith("/api/")) {
            log.info("[JWT] No Bearer token for: {} {}", request.getMethod(), requestUri);
        }

        filterChain.doFilter(request, response);
    }
}

