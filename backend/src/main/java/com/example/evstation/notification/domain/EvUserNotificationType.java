package com.example.evstation.notification.domain;

/**
 * Type of notifications sent to EV users.
 */
public enum EvUserNotificationType {
    // BOOKING
    BOOKING_CONFIRMED,
    BOOKING_EXPIRED,
    BOOKING_CANCELLED,
    BOOKING_REMINDER,
    PAYMENT_SUCCESS,
    PAYMENT_FAILED,

    // BATTERY_SWAP
    SWAP_RESERVED,
    SWAP_ARRIVED,
    SWAP_CODE_GENERATED,
    SWAP_COMPLETED,
    SWAP_REMINDER,
    SWAP_EXPIRED,

    // STATION
    ISSUE_REPORTED,
    ISSUE_ACKNOWLEDGED,
    ISSUE_RESOLVED,
    CR_SUBMITTED,
    CR_APPROVED,
    CR_REJECTED,
    CR_PUBLISHED,
    STATION_TRUST_LOW,

    // SYSTEM
    SYSTEM_ANNOUNCEMENT;

    /**
     * Get the category for this notification type.
     */
    public EvUserNotificationCategory getCategory() {
        switch (this) {
            case BOOKING_CONFIRMED:
            case BOOKING_EXPIRED:
            case BOOKING_CANCELLED:
            case BOOKING_REMINDER:
            case PAYMENT_SUCCESS:
            case PAYMENT_FAILED:
                return EvUserNotificationCategory.BOOKING;

            case SWAP_RESERVED:
            case SWAP_ARRIVED:
            case SWAP_CODE_GENERATED:
            case SWAP_COMPLETED:
            case SWAP_REMINDER:
            case SWAP_EXPIRED:
                return EvUserNotificationCategory.BATTERY_SWAP;

            case ISSUE_REPORTED:
            case ISSUE_ACKNOWLEDGED:
            case ISSUE_RESOLVED:
            case CR_SUBMITTED:
            case CR_APPROVED:
            case CR_REJECTED:
            case CR_PUBLISHED:
            case STATION_TRUST_LOW:
                return EvUserNotificationCategory.STATION;

            case SYSTEM_ANNOUNCEMENT:
            default:
                return EvUserNotificationCategory.SYSTEM;
        }
    }
}
