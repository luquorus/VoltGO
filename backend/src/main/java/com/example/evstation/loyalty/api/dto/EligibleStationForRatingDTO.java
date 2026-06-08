package com.example.evstation.loyalty.api.dto;

import com.example.evstation.loyalty.infrastructure.jpa.RatingEligibilityEntity;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
public class EligibleStationForRatingDTO {
    private String stationId;
    private String eligibilityId;
    private String stationName;
    private String stationAddress;
    private Instant eligibleAt;
    private String sourceType;
    private String sourceId;
    private Boolean isRated;

    public static EligibleStationForRatingDTO fromEntity(RatingEligibilityEntity e, String stationName, String stationAddress) {
        return EligibleStationForRatingDTO.builder()
                .stationId(e.getStationId().toString())
                .eligibilityId(e.getId().toString())
                .stationName(stationName != null ? stationName : "Unknown Station")
                .stationAddress(stationAddress != null ? stationAddress : "")
                .eligibleAt(e.getEligibleAt())
                .sourceType(e.getSourceType().name())
                .sourceId(e.getSourceId().toString())
                .isRated(e.getIsRated())
                .build();
    }
}
