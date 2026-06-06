package com.example.evstation.auth.application;

import com.example.evstation.auth.application.port.PasswordEncoder;
import com.example.evstation.auth.application.port.UserAccountRepository;
import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserAccount;
import com.example.evstation.auth.domain.UserStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class RegisterUseCase {
    private final UserAccountRepository repository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public UserAccount execute(String email, String name, String password, Role role) {
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

        // Collaborator accounts start as PENDING_COLLABORATOR (awaiting admin approval),
        // EV_USER accounts are immediately ACTIVE
        UserStatus initialStatus = (role == Role.COLLABORATOR)
                ? UserStatus.PENDING_COLLABORATOR
                : UserStatus.ACTIVE;

        UserAccount account = new UserAccount(
                email,
                name != null ? name : email,
                passwordHash,
                role,
                initialStatus);

        return repository.save(account);
    }
}

