package com.example.evstation.auth.api;

import com.example.evstation.auth.api.dto.AuthResponse;
import com.example.evstation.auth.api.dto.LoginRequest;
import com.example.evstation.auth.api.dto.RegisterRequest;
import com.example.evstation.auth.application.LoginUseCase;
import com.example.evstation.auth.application.RegisterUseCase;
import com.example.evstation.auth.application.port.UserAccountRepository;
import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.domain.UserAccount;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Authentication", description = "Public authentication endpoints")
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {
    private final RegisterUseCase registerUseCase;
    private final LoginUseCase loginUseCase;
    private final UserAccountRepository userAccountRepository;

    @Operation(summary = "Register new user", description = "Register EV_USER, PROVIDER, or COLLABORATOR")
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        Role role;
        try {
            role = Role.valueOf(request.getRole().toUpperCase());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        }

        UserAccount account = registerUseCase.execute(
                request.getEmail(), 
                request.getName(), 
                request.getPassword(), 
                role);
        
        // Generate token for registered user
        String token = loginUseCase.execute(request.getEmail(), request.getPassword())
                .orElse(null);
        
        AuthResponse response = AuthResponse.builder()
                .token(token)
                .userId(account.getId())
                .email(account.getEmail())
                .name(account.getName())
                .role(account.getRole().name())
                .build();

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(summary = "Login", description = "Login and get JWT token")
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return loginUseCase.execute(request.getEmail(), request.getPassword())
                .map(token -> {
                    UserAccount account = userAccountRepository.findByEmail(request.getEmail())
                            .orElseThrow();
                    
                    return ResponseEntity.ok(AuthResponse.builder()
                            .token(token)
                            .userId(account.getId())
                            .email(account.getEmail())
                            .name(account.getName())
                            .role(account.getRole().name())
                            .build());
                })
                .orElse(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }
}

