package com.example.evstation.auth.application;

import com.example.evstation.auth.api.dto.ChangePasswordRequest;
import com.example.evstation.auth.api.dto.UpdateProfileRequest;
import com.example.evstation.auth.api.dto.UserProfileDTO;
import com.example.evstation.auth.application.port.PasswordEncoder;
import com.example.evstation.auth.application.port.UserAccountRepository;
import com.example.evstation.auth.domain.UserAccount;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserProfileService {
    private final UserAccountRepository userAccountRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public Optional<UserProfileDTO> getProfile(UUID userId) {
        return userAccountRepository.findById(userId)
                .map(account -> UserProfileDTO.builder()
                        .userId(account.getId())
                        .email(account.getEmail())
                        .name(account.getName())
                        .phone(account.getPhone())
                        .role(account.getRole().name())
                        .build());
    }

    @Transactional
    public Optional<UserProfileDTO> updateProfile(UUID userId, UpdateProfileRequest request) {
        return userAccountRepository.findById(userId)
                .map(account -> {
                    account.setName(request.getName());
                    account.setPhone(request.getPhone());
                    UserAccount updated = userAccountRepository.save(account);
                    
                    log.info("Profile updated: userId={}, name={}, phone={}", userId, request.getName(), request.getPhone());
                    
                    return UserProfileDTO.builder()
                            .userId(updated.getId())
                            .email(updated.getEmail())
                            .name(updated.getName())
                            .phone(updated.getPhone())
                            .role(updated.getRole().name())
                            .build();
                });
    }

    @Transactional
    public boolean changePassword(UUID userId, ChangePasswordRequest request) {
        return userAccountRepository.findById(userId)
                .map(account -> {
                    // Verify current password
                    if (!passwordEncoder.matches(request.getCurrentPassword(), account.getPasswordHash())) {
                        log.warn("Password change failed: incorrect current password for userId={}", userId);
                        return false;
                    }

                    // Update password
                    String newPasswordHash = passwordEncoder.encode(request.getNewPassword());
                    account.setPasswordHash(newPasswordHash);
                    userAccountRepository.save(account);
                    
                    log.info("Password changed successfully for userId={}", userId);
                    return true;
                })
                .orElse(false);
    }
}

