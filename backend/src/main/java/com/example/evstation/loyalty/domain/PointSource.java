package com.example.evstation.loyalty.domain;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum PointSource {
    BOOKING(30, "Completed charging session"),
    BATTERY_SWAP(30, "Completed battery swap"),
    RATING(10, "Rated a station"),
    RATING_WITH_COMMENT(5, "Rating with written review"),
    CR_SUBMIT(10, "Submitted station update proposal"),
    CR_PUBLISH(40, "Proposal approved and published"),
    REFERRAL(50, "Successful referral"),
    BADGE(0, "Badge earned"),
    ADMIN_ADJUST(0, "Manual adjustment by admin"),
    VOUCHER_REDEMPTION(0, "Voucher redemption");

    private final int basePoints;
    private final String description;
}
