package com.example.evstation.auth.application;

import com.example.evstation.auth.application.port.PasswordEncoder;
import com.example.evstation.auth.application.port.UserAccountRepository;
import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserAccount;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class RegisterUseCase {
    private final UserAccountRepository repository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public UserAccount execute(String email, String password, Role role) {
        // Validate role
        if (role == Role.ADMIN) {
            throw new IllegalArgumentException("Cannot register as ADMIN");
        }

        // Check email exists
        if (repository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already exists");
        }

        // Create account
        String passwordHash = passwordEncoder.encode(password);
        UserAccount account = new UserAccount(email, passwordHash, role);
        
        return repository.save(account);
    }
}

