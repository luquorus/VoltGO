package com.example.evstation.auth.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {
    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    private String name; // Optional, defaults to email if not provided

    @NotBlank(message = "Password is required")
    @Size(min = 8, message = "Password must be at least 8 characters")
    @Pattern(
        regexp = "^(?=.*[A-Z])(?=.*[a-z])(?=.*\\d)(?=.*[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?]).*$",
        message = "Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character (!@#$%^&*)"
    )
    private String password;

    @NotBlank(message = "Role is required")
    private String role; // EV_USER, COLLABORATOR

    private String referralCode; // optional referral code used during EV_USER registration
}
