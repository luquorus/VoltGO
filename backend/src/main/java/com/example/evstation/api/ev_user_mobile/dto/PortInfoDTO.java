package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class PortInfoDTO {
    private String powerType; // DC or AC
    private BigDecimal powerKw; // null for AC
    private Integer count;
}

