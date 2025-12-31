package com.example.evstation.auth.infrastructure.jpa;

import com.example.evstation.auth.application.port.UserAccountRepository;
import com.example.evstation.auth.domain.UserAccount;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class UserAccountRepositoryAdapter implements UserAccountRepository {
    private final UserAccountJpaRepository jpaRepository;

    @Override
    public UserAccount save(UserAccount userAccount) {
        UserAccountEntity entity = toEntity(userAccount);
        UserAccountEntity saved = jpaRepository.save(entity);
        return toDomain(saved);
    }

    @Override
    public Optional<UserAccount> findById(UUID id) {
        return jpaRepository.findById(id)
                .map(this::toDomain);
    }

    @Override
    public Optional<UserAccount> findByEmail(String email) {
        return jpaRepository.findByEmail(email)
                .map(this::toDomain);
    }

    @Override
    public boolean existsByEmail(String email) {
        return jpaRepository.existsByEmail(email);
    }

    private UserAccountEntity toEntity(UserAccount domain) {
        return UserAccountEntity.builder()
                .id(domain.getId())
                .email(domain.getEmail())
                .passwordHash(domain.getPasswordHash())
                .role(domain.getRole())
                .status(domain.getStatus())
                .createdAt(domain.getCreatedAt())
                .build();
    }

    private UserAccount toDomain(UserAccountEntity entity) {
        return new UserAccount(
                entity.getId(),
                entity.getEmail(),
                entity.getPasswordHash(),
                entity.getRole(),
                entity.getStatus(),
                entity.getCreatedAt()
        );
    }
}

