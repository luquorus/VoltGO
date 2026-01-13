package com.example.evstation.auth.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {
    @NotBlank
    @Email
    private String email;

    private String name; // Optional, defaults to email if not provided

    @NotBlank
    @Size(min = 8)
    private String password;

    @NotBlank
    private String role; // EV_USER, PROVIDER, COLLABORATOR
}

