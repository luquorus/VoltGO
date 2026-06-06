package com.example.evstation.loyalty.api.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class ReferralCodeDTO {
    private String code;
    private String referralLink;
}
