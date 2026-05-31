package com.example.evstation.batteryswap.domain;

public enum BatteryEventType {
    BATTERY_INSERTED,
    BATTERY_REMOVED,
    CHARGING_STARTED,
    CHARGING_COMPLETED,
    RESERVED,
    UNRESERVED,
    SWAPPED_IN,
    SWAPPED_OUT,
    STATUS_CHANGED,
    FULLY_CHARGED,
    SLOT_LOCKED,
    SLOT_UNLOCKED
}
