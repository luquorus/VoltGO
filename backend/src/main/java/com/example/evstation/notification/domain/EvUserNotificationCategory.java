package com.example.evstation.notification.domain;

/**
 * Category of notifications for EV users for filtering and preferences.
 */
public enum EvUserNotificationCategory {
    ALL,          // System-wide / all types
    BOOKING,      // Booking related
    BATTERY_SWAP, // Battery swap related
    STATION,      // Station related
    SYSTEM,       // System announcements
}
