package com.example.evstation.auth.application;

import com.example.evstation.auth.application.port.PasswordEncoder;
import com.example.evstation.auth.application.port.UserAccountRepository;
import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserAccount;
import com.example.evstation.auth.domain.UserStatus;
import com.example.evstation.loyalty.application.ReferralService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class RegisterUseCase {
    private final UserAccountRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final ReferralService referralService;

    @Transactional
    public UserAccount execute(String email, String name, String password, Role role, String referralCode) {
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

        account = repository.save(account);

        // Process referral if EV_USER registered with a referral code
        if (role == Role.EV_USER && referralCode != null && !referralCode.isBlank()) {
            log.info("REGISTER_USE_CASE: EV_USER registered with referralCode='{}', email='{}', userId={}",
                    referralCode, email, account.getId());
            referralService.onReferralSignup(referralCode.trim(), account.getId());
        } else {
            log.info("REGISTER_USE_CASE: No referral code - role={}, referralCode='{}', email='{}'",
                    role, referralCode, email);
        }

        return account;
    }
}

