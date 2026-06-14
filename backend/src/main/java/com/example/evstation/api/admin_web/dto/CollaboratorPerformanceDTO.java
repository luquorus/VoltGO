package com.example.evstation.api.admin_web.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CollaboratorPerformanceDTO {
    private UUID collaboratorId;
    private String fullName;
    private long totalTasks;
    private double passRate;
    private double avgCompletionTimeHours;
    private double avgDistanceMeters;
    private double slaComplianceRate;

    /** Tổng số Change Request mà collaborator đã gửi (charging + battery swap). */
    private long totalChangeRequests;
    /** Số CR đã được publish (tính cả charging + battery swap). */
    private long publishedChangeRequests;
    /** Số CR đã bị admin từ chối. */
    private long rejectedChangeRequests;
    /** Tỉ lệ publish = published / total (0 nếu total = 0). Đơn vị: %. */
    private double changeRequestPublishRate;
}
