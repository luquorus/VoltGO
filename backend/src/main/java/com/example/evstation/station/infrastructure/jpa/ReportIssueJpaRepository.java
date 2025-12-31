package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.station.domain.IssueStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ReportIssueJpaRepository extends JpaRepository<ReportIssueEntity, UUID> {
    
    // Find issues by reporter
    Page<ReportIssueEntity> findByReporterIdOrderByCreatedAtDesc(UUID reporterId, Pageable pageable);
    
    List<ReportIssueEntity> findByReporterIdOrderByCreatedAtDesc(UUID reporterId);
    
    // Find issues by status
    Page<ReportIssueEntity> findByStatusOrderByCreatedAtDesc(IssueStatus status, Pageable pageable);
    
    List<ReportIssueEntity> findByStatusOrderByCreatedAtDesc(IssueStatus status);
    
    // Find issues by station
    List<ReportIssueEntity> findByStationIdOrderByCreatedAtDesc(UUID stationId);
    
    // Find open/acknowledged issues by station (for trust score calculation)
    @Query("""
        SELECT ri FROM ReportIssueEntity ri 
        WHERE ri.stationId = :stationId 
        AND ri.status IN ('OPEN', 'ACKNOWLEDGED')
        ORDER BY ri.createdAt DESC
        """)
    List<ReportIssueEntity> findUnresolvedByStationId(@Param("stationId") UUID stationId);
    
    // Count unresolved issues by station
    @Query("""
        SELECT COUNT(ri) FROM ReportIssueEntity ri 
        WHERE ri.stationId = :stationId 
        AND ri.status IN ('OPEN', 'ACKNOWLEDGED')
        """)
    long countUnresolvedByStationId(@Param("stationId") UUID stationId);
    
    // Find all issues with optional status filter
    Page<ReportIssueEntity> findAllByOrderByCreatedAtDesc(Pageable pageable);
}

