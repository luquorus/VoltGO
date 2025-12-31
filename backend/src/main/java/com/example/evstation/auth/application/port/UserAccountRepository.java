package com.example.evstation.auth.application.port;

import com.example.evstation.auth.domain.UserAccount;

import java.util.Optional;
import java.util.UUID;

public interface UserAccountRepository {
    UserAccount save(UserAccount userAccount);
    Optional<UserAccount> findById(UUID id);
    Optional<UserAccount> findByEmail(String email);
    boolean existsByEmail(String email);
}

