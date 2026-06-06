package com.example.evstation.auth.infrastructure.security;

import com.example.evstation.auth.application.port.JwtTokenProvider;
import com.example.evstation.auth.domain.UserStatus;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
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
 * - COLLABORATOR -> ROLE_COLLABORATOR
 * - ADMIN -> ROLE_ADMIN
 * - PENDING_COLLABORATOR -> ROLE_PENDING_COLLABORATOR (limited access)
 *
 * For PENDING_COLLABORATOR tokens: verifies actual status against DB.
 * If the account has been activated (status changed to ACTIVE via admin approval),
 * the filter upgrades authority to ROLE_COLLABORATOR without requiring a new token.
 *
 * This allows approved collaborators to immediately access full API without re-login.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtTokenProvider jwtTokenProvider;
    private final UserAccountJpaRepository userAccountRepository;
    private static final String AUTH_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        String requestUri = request.getRequestURI();
        String authHeader = request.getHeader(AUTH_HEADER);

        if (authHeader != null && authHeader.startsWith(BEARER_PREFIX)) {
            String token = authHeader.substring(BEARER_PREFIX.length());
            try {
                JwtTokenProvider.TokenClaims claims = jwtTokenProvider.parseToken(token);

                String roleName = claims.role().name();
                String authority;

                if (claims.status() == UserStatus.PENDING_COLLABORATOR) {
                    // Verify actual status from DB — if already ACTIVE, upgrade to full COLLABORATOR
                    var dbStatus = userAccountRepository.findById(claims.userId())
                            .map(entity -> entity.getStatus())
                            .orElse(UserStatus.PENDING_COLLABORATOR);

                    if (dbStatus == UserStatus.ACTIVE) {
                        // Account was approved — grant full COLLABORATOR access
                        authority = "ROLE_" + roleName;
                        log.info("[JWT] PENDING_COLLABORATOR token but DB status=ACTIVE — upgraded to {} for userId={}",
                                authority, claims.userId());
                    } else {
                        authority = "ROLE_PENDING_COLLABORATOR";
                    }
                } else {
                    authority = "ROLE_" + roleName;
                }

                SimpleGrantedAuthority grantedAuthority = new SimpleGrantedAuthority(authority);

                UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                        claims.userId(),
                        null,
                        List.of(grantedAuthority)
                );
                authentication.setDetails(claims);

                SecurityContextHolder.getContext().setAuthentication(authentication);

                log.info("[JWT] Auth SUCCESS: uri={}, userId={}, role={}, status={}, authority={}",
                        requestUri, claims.userId(), claims.role(), claims.status(), authority);
            } catch (Exception e) {
                log.warn("[JWT] Auth FAILED: uri={}, error={}", requestUri, e.getMessage(), e);
            }
        }

        filterChain.doFilter(request, response);
    }
}

