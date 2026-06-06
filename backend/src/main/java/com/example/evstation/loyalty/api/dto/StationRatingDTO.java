package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.StationRatingEntity;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
public class StationRatingDTO {
    private String id;
    private String stationId;
    private String stationName;
    private Integer rating;
    private String comment;
    private Boolean isVerified;
    private Integer helpfulCount;
    private Instant createdAt;

    public static StationRatingDTO fromEntity(StationRatingEntity e, String stationName) {
        return StationRatingDTO.builder()
                .id(e.getId().toString())
                .stationId(e.getStationId().toString())
                .stationName(stationName != null ? stationName : "Unknown Station")
                .rating(e.getRating())
                .comment(e.getComment())
                .isVerified(e.getIsVerified())
                .helpfulCount(e.getHelpfulCount())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
