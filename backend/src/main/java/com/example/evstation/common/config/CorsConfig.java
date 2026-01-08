package com.example.evstation.common.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * CORS Configuration for Flutter Web
 * 
 * Allows Flutter web apps to make requests from browser
 */
@Configuration
public class CorsConfig {

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        
        // Use allowedOriginPatterns instead of allowedOrigins
        // This allows wildcard patterns and works with allowCredentials=true
        // Matches any port on localhost/127.0.0.1 for Flutter web development
        configuration.setAllowedOriginPatterns(Arrays.asList(
            "http://localhost:*",
            "http://127.0.0.1:*"
        ));
        
        // Allow common HTTP methods
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));
        
        // Allow all headers (needed for Authorization header)
        configuration.setAllowedHeaders(List.of("*"));
        
        // Allow credentials (cookies, authorization headers)
        configuration.setAllowCredentials(true);
        
        // Expose Authorization header in response
        configuration.setExposedHeaders(Arrays.asList("Authorization"));
        
        // Cache preflight response for 1 hour
        configuration.setMaxAge(3600L);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        
        return source;
    }
}

