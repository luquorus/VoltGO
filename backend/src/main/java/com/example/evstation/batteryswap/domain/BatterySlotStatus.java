package com.example.evstation.batteryswap.domain;

public enum BatterySlotStatus {
    AVAILABLE,
    OCCUPIED,
    CHARGING,
    RESERVED,
    /**
     * Pin đã bị user lấy đi khi hoàn thành swap.
     * Slot đang chờ được sạc lại (0%) cho đến khi đạt 100% và chuyển sang AVAILABLE.
     */
    SWAPPED_OUT
}
