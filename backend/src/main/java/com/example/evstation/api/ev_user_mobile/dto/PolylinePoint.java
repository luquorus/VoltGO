package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class PolylinePoint {
    private double lat;
    private double lng;
}
