package com.example.evstation.api.admin_web.controller;

import com.example.evstation.api.common.dto.PresignViewResponseDTO;
import com.example.evstation.common.file.FileService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@RestController
@RequestMapping("/api/admin/files")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminFileController {

    private final FileService fileService;

    @GetMapping("/presign-view")
    public ResponseEntity<PresignViewResponseDTO> getPresignViewUrl(
            @RequestParam String objectKey) {
        
        String url = fileService.generatePresignedViewUrl(objectKey, 60);
        Instant expiresAt = Instant.now().plus(60, ChronoUnit.MINUTES);
        return ResponseEntity.ok(new PresignViewResponseDTO(url, expiresAt));
    }
}
