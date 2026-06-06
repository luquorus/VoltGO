package com.example.evstation.notification.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterPushTokenDTO {
    @NotBlank
    private String token;

    @NotBlank
    private String deviceType; // ANDROID, IOS, WEB
}
