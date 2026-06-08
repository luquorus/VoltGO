package com.example.evstation.api.admin_web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BookingStatsDTO {
    private long totalBookings;
    private double completionRate;
    private double cancellationRate;
    private long revenue;
    private double avgSessionDurationMinutes;
}
