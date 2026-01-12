package com.example.evstation.verification.api.dto;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * Response DTO for collaborator candidates list.
 */
@Data
@Builder
public class CandidateListResponseDTO {
    private String taskId;
    private String stationId;
    private StationLocationDTO stationLocation;
    private List<CollaboratorCandidateDTO> candidates;
    private PageInfoDTO page;
    
    @Data
    @Builder
    public static class StationLocationDTO {
        private Double lat;
        private Double lng;
    }
    
    @Data
    @Builder
    public static class PageInfoDTO {
        private Integer page;
        private Integer size;
        private Long totalElements;
        private Integer totalPages;
        private Boolean first;
        private Boolean last;
    }
}

