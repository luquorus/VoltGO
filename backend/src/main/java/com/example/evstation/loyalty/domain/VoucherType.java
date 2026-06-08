package com.example.evstation.loyalty.domain;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum VoucherType {
    PERCENT_DISCOUNT,
    FREE_SERVICE
}
