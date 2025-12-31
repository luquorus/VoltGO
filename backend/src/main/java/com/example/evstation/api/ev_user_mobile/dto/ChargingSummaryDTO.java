package com.example.evstation.api.ev_user_mobile.dto;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
public class ChargingSummaryDTO {
    private Integer totalPorts;
    private BigDecimal maxPowerKw; // DC only, null if no DC ports
    private List<PortInfoDTO> ports;
}

