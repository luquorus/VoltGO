package com.example.evstation.api.admin_web.dto;

import com.example.evstation.station.domain.IssueCategory;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IssueStatsDTO {
    private long openCount;
    private double avgResolutionTimeHours;
    private java.util.List<IssueByCategory> issuesByCategory;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class IssueByCategory {
        private IssueCategory category;
        private long count;
    }
}
