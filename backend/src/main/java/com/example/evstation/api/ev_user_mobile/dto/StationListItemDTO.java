package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class StationListItemDTO {
    private String stationId;
    private String name;
    private String address;
    private Double lat;
    private Double lng;
    private String operatingHours;
    private String parking; // PAID, FREE, UNKNOWN
    private String visibility; // PUBLIC, PRIVATE, RESTRICTED
    private String publicStatus; // ACTIVE, INACTIVE, MAINTENANCE
    private ChargingSummaryDTO chargingSummary;
    private Integer trustScore; // tạm 50
}

