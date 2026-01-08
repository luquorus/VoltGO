package com.example.evstation.auth.infrastructure.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

import java.time.Instant;
import java.util.Map;

/**
 * Spring Security Configuration
 * 
 * Security rules:
 * - Public: /healthz, /actuator/**, /swagger-ui/**, /v3/api-docs/**, /auth/**, /debug/**
 * - Authenticated: /api/** (role-based access controlled by @PreAuthorize)
 * 
 * JWT authentication is handled by JwtAuthenticationFilter which:
 * - Extracts Bearer token from Authorization header
 * - Maps JWT "role" claim to Spring Security GrantedAuthority (ROLE_*)
 * - Sets authentication in SecurityContext
 * 
 * Method-level security (@PreAuthorize) is enabled for fine-grained role-based access control.
 */
@Slf4j
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)
@RequiredArgsConstructor
public class SecurityConfig {
    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final ObjectMapper objectMapper;
    private final org.springframework.web.cors.CorsConfigurationSource corsConfigurationSource;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource))
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // Health and actuator - public
                        .requestMatchers("/healthz", "/actuator/**").permitAll()
                        
                        // Swagger/OpenAPI - public (must be before /api/**)
                        .requestMatchers(
                                "/swagger-ui.html",
                                "/swagger-ui/**",
                                "/swagger-ui/index.html",
                                "/v3/api-docs",
                                "/v3/api-docs/**",
                                "/api-docs",
                                "/api-docs/**"
                        ).permitAll()
                        
                        // Auth endpoints - public
                        .requestMatchers("/auth/**").permitAll()
                        
                        // Debug endpoints - public (for troubleshooting)
                        .requestMatchers("/debug/**").permitAll()
                        
                        // API endpoints - require authentication
                        // Role-based access is controlled by @PreAuthorize on controller methods
                        // EV_USER and PROVIDER can access /api/ev/stations and /api/ev/stations/{id}
                        .requestMatchers("/api/**").authenticated()
                        
                        // Everything else requires authentication
                        .anyRequest().authenticated()
                )
                // JWT authentication filter runs before UsernamePasswordAuthenticationFilter
                // It extracts Bearer token, validates, and sets SecurityContext
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                
                // Exception handling for 401/403 with detailed logging
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((request, response, authException) -> {
                            log.warn("[Security] 401 Unauthorized: uri={}, error={}", 
                                    request.getRequestURI(), authException.getMessage());
                            
                            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                            response.getWriter().write(objectMapper.writeValueAsString(Map.of(
                                    "code", "EVS-0401",
                                    "message", "Unauthorized: " + authException.getMessage(),
                                    "timestamp", Instant.now().toString()
                            )));
                        })
                        .accessDeniedHandler((request, response, accessDeniedException) -> {
                            var auth = SecurityContextHolder.getContext().getAuthentication();
                            log.warn("[Security] 403 Forbidden: uri={}, principal={}, authorities={}, error={}", 
                                    request.getRequestURI(),
                                    auth != null ? auth.getPrincipal() : "null",
                                    auth != null ? auth.getAuthorities() : "null",
                                    accessDeniedException.getMessage());
                            
                            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                            response.getWriter().write(objectMapper.writeValueAsString(Map.of(
                                    "code", "EVS-0403",
                                    "message", "Access denied: " + accessDeniedException.getMessage(),
                                    "principal", auth != null ? auth.getPrincipal().toString() : "null",
                                    "authorities", auth != null ? auth.getAuthorities().toString() : "null",
                                    "timestamp", Instant.now().toString()
                            )));
                        })
                );

        return http.build();
    }
}

