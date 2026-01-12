package com.example.evstation.verification.application;

import com.example.evstation.auth.domain.Role;
import com.example.evstation.auth.infrastructure.jpa.UserAccountEntity;
import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.collaborator.api.dto.CollaboratorLocationDTO;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileEntity;
import com.example.evstation.collaborator.infrastructure.jpa.CollaboratorProfileJpaRepository;
import com.example.evstation.collaborator.infrastructure.jpa.ContractJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import com.example.evstation.verification.api.dto.CandidateListResponseDTO;
import com.example.evstation.verification.api.dto.CollaboratorCandidateDTO;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskEntity;
import com.example.evstation.verification.infrastructure.jpa.VerificationTaskJpaRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Query service for listing collaborator candidates for task assignment.
 * Computes distance to station using PostGIS and aggregates workload statistics.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CollaboratorCandidateQueryService {
    
    private final VerificationTaskJpaRepository taskRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final CollaboratorProfileJpaRepository collaboratorRepository;
    private final ContractJpaRepository contractRepository;
    private final UserAccountJpaRepository userAccountRepository;
    private final EntityManager entityManager;
    private final Clock clock;

    /**
     * List collaborator candidates for a verification task.
     * 
     * @param taskId The task ID
     * @param onlyActiveContract Filter to only show collaborators with active contracts
     * @param includeUnlocated Include collaborators without location data
     * @param pageable Pagination parameters
     * @return Candidate list response with distance and stats
     */
    @Transactional(readOnly = true)
    public CandidateListResponseDTO listCandidatesForTask(
            UUID taskId,
            boolean onlyActiveContract,
            boolean includeUnlocated,
            Pageable pageable) {
        
        log.info("Listing candidates for task: taskId={}, onlyActiveContract={}, includeUnlocated={}", 
                taskId, onlyActiveContract, includeUnlocated);
        
        // Get task
        VerificationTaskEntity task = taskRepository.findById(taskId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Task not found"));
        
        // Get station published version location
        StationVersionEntity stationVersion = stationVersionRepository.findPublishedByStationId(task.getStationId())
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_STATE, 
                        "Station has no published version"));
        
        Double stationLat = stationVersion.getLocation() != null ? stationVersion.getLocation().getY() : null;
        Double stationLng = stationVersion.getLocation() != null ? stationVersion.getLocation().getX() : null;
        
        if (stationLat == null || stationLng == null) {
            throw new BusinessException(ErrorCode.INVALID_STATE, "Station has no location");
        }
        
        LocalDate today = LocalDate.now(clock);
        Instant thirtyDaysAgo = Instant.now(clock).minus(30, ChronoUnit.DAYS);
        
        // Get all collaborator profiles with user accounts having COLLABORATOR role
        List<CollaboratorProfileEntity> allProfiles = getCollaboratorProfiles(
                onlyActiveContract, includeUnlocated, today);
        
        // Compute distances using PostGIS
        Map<UUID, Integer> distanceMap = computeDistances(allProfiles, stationLat, stationLng);
        
        // Get workload statistics
        Map<UUID, CollaboratorCandidateDTO.CandidateStatsDTO> statsMap = 
                computeWorkloadStats(allProfiles, thirtyDaysAgo);
        
        // Build candidate DTOs
        List<CollaboratorCandidateDTO> candidates = allProfiles.stream()
                .map(profile -> buildCandidateDTO(profile, distanceMap, statsMap, today))
                .collect(Collectors.toList());
        
        // Sort: distance ASC (nulls last), then active ASC, then completed DESC
        candidates.sort((a, b) -> {
            // Distance: nulls last
            if (a.getDistanceMeters() == null && b.getDistanceMeters() == null) {
                // Both null - compare by active count
                int activeCompare = compareNullSafe(a.getStats().getActive(), b.getStats().getActive());
                if (activeCompare != 0) return activeCompare;
                // Then by completed DESC
                return compareNullSafe(b.getStats().getCompleted(), a.getStats().getCompleted());
            }
            if (a.getDistanceMeters() == null) return 1;  // a goes after b
            if (b.getDistanceMeters() == null) return -1; // b goes after a
            
            int distCompare = a.getDistanceMeters().compareTo(b.getDistanceMeters());
            if (distCompare != 0) return distCompare;
            
            // Tie-break by active count ASC
            int activeCompare = compareNullSafe(a.getStats().getActive(), b.getStats().getActive());
            if (activeCompare != 0) return activeCompare;
            
            // Tie-break by completed DESC
            return compareNullSafe(b.getStats().getCompleted(), a.getStats().getCompleted());
        });
        
        // Apply pagination
        int start = (int) pageable.getOffset();
        int end = Math.min(start + pageable.getPageSize(), candidates.size());
        List<CollaboratorCandidateDTO> pagedCandidates = 
                start < candidates.size() ? candidates.subList(start, end) : List.of();
        
        Page<CollaboratorCandidateDTO> candidatePage = new PageImpl<>(
                pagedCandidates, pageable, candidates.size());
        
        return CandidateListResponseDTO.builder()
                .taskId(taskId.toString())
                .stationId(task.getStationId().toString())
                .stationLocation(CandidateListResponseDTO.StationLocationDTO.builder()
                        .lat(stationLat)
                        .lng(stationLng)
                        .build())
                .candidates(pagedCandidates)
                .page(CandidateListResponseDTO.PageInfoDTO.builder()
                        .page(candidatePage.getNumber())
                        .size(candidatePage.getSize())
                        .totalElements(candidatePage.getTotalElements())
                        .totalPages(candidatePage.getTotalPages())
                        .first(candidatePage.isFirst())
                        .last(candidatePage.isLast())
                        .build())
                .build();
    }

    private List<CollaboratorProfileEntity> getCollaboratorProfiles(
            boolean onlyActiveContract, boolean includeUnlocated, LocalDate today) {
        
        // Get all users with COLLABORATOR role
        List<UserAccountEntity> collaboratorUsers = userAccountRepository.findByRole(Role.COLLABORATOR);
        Set<UUID> collaboratorUserIds = collaboratorUsers.stream()
                .map(UserAccountEntity::getId)
                .collect(Collectors.toSet());
        
        // Get all profiles for these users
        List<CollaboratorProfileEntity> profiles = collaboratorRepository.findAll().stream()
                .filter(p -> collaboratorUserIds.contains(p.getUserAccountId()))
                .collect(Collectors.toList());
        
        // Filter by location if needed
        if (!includeUnlocated) {
            profiles = profiles.stream()
                    .filter(p -> p.getCurrentLocation() != null)
                    .collect(Collectors.toList());
        }
        
        // Filter by active contract if needed
        if (onlyActiveContract) {
            profiles = profiles.stream()
                    .filter(p -> contractRepository.hasEffectiveActiveContract(p.getId(), today))
                    .collect(Collectors.toList());
        }
        
        return profiles;
    }

    private Map<UUID, Integer> computeDistances(
            List<CollaboratorProfileEntity> profiles, Double stationLat, Double stationLng) {
        
        Map<UUID, Integer> distances = new HashMap<>();
        
        for (CollaboratorProfileEntity profile : profiles) {
            if (profile.getCurrentLocation() == null) {
                distances.put(profile.getUserAccountId(), null);
                continue;
            }
            
            try {
                String sql = """
                    SELECT CAST(ST_Distance(
                        CAST(ST_SetSRID(ST_MakePoint(?1, ?2), 4326) AS geography),
                        CAST(ST_SetSRID(ST_MakePoint(?3, ?4), 4326) AS geography)
                    ) AS INTEGER) as distance
                    """;
                
                Query query = entityManager.createNativeQuery(sql);
                query.setParameter(1, stationLng);
                query.setParameter(2, stationLat);
                query.setParameter(3, profile.getLongitude());
                query.setParameter(4, profile.getLatitude());
                
                Object result = query.getSingleResult();
                Integer distance = result != null ? ((Number) result).intValue() : null;
                distances.put(profile.getUserAccountId(), distance);
            } catch (Exception e) {
                log.warn("Failed to compute distance for collaborator {}: {}", 
                        profile.getUserAccountId(), e.getMessage());
                distances.put(profile.getUserAccountId(), null);
            }
        }
        
        return distances;
    }

    private Map<UUID, CollaboratorCandidateDTO.CandidateStatsDTO> computeWorkloadStats(
            List<CollaboratorProfileEntity> profiles, Instant thirtyDaysAgo) {
        
        Map<UUID, CollaboratorCandidateDTO.CandidateStatsDTO> statsMap = new HashMap<>();
        Instant now = Instant.now(clock);
        
        for (CollaboratorProfileEntity profile : profiles) {
            UUID userId = profile.getUserAccountId();
            
            // Get all tasks for this collaborator
            List<VerificationTaskEntity> tasks = taskRepository.findByAssignedTo(userId);
            
            int completed = 0;
            int active = 0;
            int failedOrOverdue = 0;
            
            for (VerificationTaskEntity task : tasks) {
                switch (task.getStatus()) {
                    case REVIEWED:
                        completed++;
                        // Check if failed in last 30 days
                        // Note: need to check review result
                        break;
                    case ASSIGNED:
                    case CHECKED_IN:
                    case SUBMITTED:
                        active++;
                        // Check if overdue
                        if (task.getSlaDueAt() != null && task.getSlaDueAt().isBefore(now)) {
                            failedOrOverdue++;
                        }
                        break;
                    default:
                        break;
                }
            }
            
            statsMap.put(userId, CollaboratorCandidateDTO.CandidateStatsDTO.builder()
                    .completed(completed)
                    .active(active)
                    .failedOrOverdue(failedOrOverdue)
                    .build());
        }
        
        return statsMap;
    }

    private CollaboratorCandidateDTO buildCandidateDTO(
            CollaboratorProfileEntity profile,
            Map<UUID, Integer> distanceMap,
            Map<UUID, CollaboratorCandidateDTO.CandidateStatsDTO> statsMap,
            LocalDate today) {
        
        UUID userId = profile.getUserAccountId();
        
        // Build location DTO
        CollaboratorLocationDTO locationDTO = null;
        if (profile.getCurrentLocation() != null) {
            locationDTO = CollaboratorLocationDTO.builder()
                    .lat(profile.getLatitude())
                    .lng(profile.getLongitude())
                    .updatedAt(profile.getLocationUpdatedAt())
                    .source(profile.getLocationSource() != null ? profile.getLocationSource().name() : null)
                    .build();
        }
        
        boolean hasActiveContract = contractRepository.hasEffectiveActiveContract(profile.getId(), today);
        
        return CollaboratorCandidateDTO.builder()
                .collaboratorUserId(userId.toString())
                .profileId(profile.getId().toString())
                .fullName(profile.getFullName())
                .phone(profile.getPhone())
                .contractActive(hasActiveContract)
                .location(locationDTO)
                .distanceMeters(distanceMap.get(userId))
                .stats(statsMap.getOrDefault(userId, CollaboratorCandidateDTO.CandidateStatsDTO.builder()
                        .completed(0)
                        .active(0)
                        .failedOrOverdue(0)
                        .build()))
                .build();
    }

    private int compareNullSafe(Integer a, Integer b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
    }
}

