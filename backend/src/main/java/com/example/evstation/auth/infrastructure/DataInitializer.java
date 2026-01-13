package com.example.evstation.auth.infrastructure;

import com.example.evstation.auth.application.port.PasswordEncoder;
import com.example.evstation.auth.application.port.UserAccountRepository;
import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserAccount;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class DataInitializer implements CommandLineRunner {
    private final UserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
        String adminEmail = "admin@local";
        
        // Check if admin already exists
        if (userAccountRepository.existsByEmail(adminEmail)) {
            log.info("Admin user already exists: {}", adminEmail);
            return;
        }

        // Create admin user
        String passwordHash = passwordEncoder.encode("Admin@123");
        UserAccount admin = new UserAccount(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                adminEmail,
                "Admin",
                null, // phone
                passwordHash,
                Role.ADMIN,
                com.example.evstation.auth.domain.UserStatus.ACTIVE,
                java.time.Instant.now()
        );

        userAccountRepository.save(admin);
        log.info("Admin user created: {} / Admin@123", adminEmail);
    }
}

