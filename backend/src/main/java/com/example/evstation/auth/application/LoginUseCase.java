package com.example.evstation.auth.application;

import com.example.evstation.auth.application.port.JwtTokenProvider;
import com.example.evstation.auth.application.port.PasswordEncoder;
import com.example.evstation.auth.application.port.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class LoginUseCase {
    private final UserAccountRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    public Optional<String> execute(String email, String password) {
        return repository.findByEmail(email)
                .filter(account -> account.isActive())
                .filter(account -> passwordEncoder.matches(password, account.getPasswordHash()))
                .map(account -> jwtTokenProvider.generateToken(
                        account.getId(),
                        account.getEmail(),
                        account.getRole()
                ));
    }
}

