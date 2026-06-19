package com.example.evstation.api.ev_user_mobile.controller;

import com.example.evstation.api.common.dto.PresignViewResponseDTO;
import com.example.evstation.common.file.FileService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@RestController
@RequestMapping("/api/ev/files")
@RequiredArgsConstructor
@PreAuthorize("hasRole('EV_USER')")
public class EvFileController {

    private final FileService fileService;

    @GetMapping("/presign-view")
    public ResponseEntity<PresignViewResponseDTO> getPresignViewUrl(
            @RequestParam String objectKey,
            @RequestParam(defaultValue = "60") int expiresInMinutes) {

        String url = fileService.generatePresignedViewUrl(objectKey, expiresInMinutes);
        Instant expiresAt = Instant.now().plus(expiresInMinutes, ChronoUnit.MINUTES);
        return ResponseEntity.ok(new PresignViewResponseDTO(url, expiresAt));
    }
}
