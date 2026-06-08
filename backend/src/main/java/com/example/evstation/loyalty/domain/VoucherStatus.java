package com.example.evstation.loyalty.domain;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum VoucherStatus {
    ACTIVE,
    INACTIVE,
    ARCHIVED
}
