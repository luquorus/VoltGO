package com.example.evstation.collaborator.api.dto;

import lombok.Builder;
import lombok.Data;

import java.time.Instant;

/**
 * DTO for collaborator location response.
 */
@Data
@Builder
public class CollaboratorLocationDTO {
    private Double lat;
    private Double lng;
    private Instant updatedAt;
    private String source;
}

