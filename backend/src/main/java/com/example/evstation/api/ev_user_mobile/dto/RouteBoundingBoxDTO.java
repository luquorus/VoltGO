package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class RouteBoundingBoxDTO {
    private double minLat;
    private double maxLat;
    private double minLng;
    private double maxLng;
}
