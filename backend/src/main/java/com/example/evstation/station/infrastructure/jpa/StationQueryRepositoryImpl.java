package com.example.evstation.station.infrastructure.jpa;

import com.example.evstation.api.ev_user_mobile.dto.ChargingSummaryDTO;
import com.example.evstation.api.ev_user_mobile.dto.PortInfoDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationListItemDTO;
import com.example.evstation.station.application.port.StationQueryRepository;
import com.example.evstation.station.domain.PowerType;
import com.example.evstation.trust.infrastructure.jpa.StationTrustJpaRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.Query;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;

@Repository
@RequiredArgsConstructor
public class StationQueryRepositoryImpl implements StationQueryRepository {

    @PersistenceContext
    private final EntityManager entityManager;
    
    private final StationTrustJpaRepository trustRepository;

    @Override
    public Page<StationListItemDTO> findPublishedStationsWithinRadius(
            double lat,
            double lng,
            double radiusKm,
            BigDecimal minPowerKw,
            Boolean hasAC,
            Pageable pageable) {

        // Convert radius from km to meters
        double radiusMeters = radiusKm * 1000;

        // Build base query with PostGIS ST_DWithin
        StringBuilder queryBuilder = new StringBuilder("""
            SELECT 
                sv.station_id,
                sv.name,
                sv.address,
                ST_Y(CAST(sv.location AS geometry)) as lat,
                ST_X(CAST(sv.location AS geometry)) as lng,
                sv.operating_hours,
                sv.parking,
                sv.visibility,
                sv.public_status
            FROM station_version sv
            WHERE sv.workflow_status = 'PUBLISHED'
            AND ST_DWithin(
                CAST(sv.location AS geography),
                CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
                :radiusMeters
            )
            """);

        // Add filters
        if (minPowerKw != null) {
            queryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'DC'
                    AND cp.power_kw >= :minPowerKw
                )
                """);
        }

        if (hasAC != null && hasAC) {
            queryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'AC'
                )
                """);
        }

        // Count query - build same WHERE clause
        StringBuilder countQueryBuilder = new StringBuilder("""
            SELECT COUNT(DISTINCT sv.station_id)
            FROM station_version sv
            WHERE sv.workflow_status = 'PUBLISHED'
            AND ST_DWithin(
                CAST(sv.location AS geography),
                CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
                :radiusMeters
            )
            """);
        
        if (minPowerKw != null) {
            countQueryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'DC'
                    AND cp.power_kw >= :minPowerKw
                )
                """);
        }

        if (hasAC != null && hasAC) {
            countQueryBuilder.append("""
                AND EXISTS (
                    SELECT 1 FROM station_service ss
                    JOIN charging_port cp ON ss.id = cp.station_service_id
                    WHERE ss.station_version_id = sv.id
                    AND cp.power_type = 'AC'
                )
                """);
        }
        
        Query countNativeQuery = entityManager.createNativeQuery(countQueryBuilder.toString());
        countNativeQuery.setParameter("lat", lat);
        countNativeQuery.setParameter("lng", lng);
        countNativeQuery.setParameter("radiusMeters", radiusMeters);
        if (minPowerKw != null) {
            countNativeQuery.setParameter("minPowerKw", minPowerKw);
        }
        long total = ((Number) countNativeQuery.getSingleResult()).longValue();

        // Add pagination
        queryBuilder.append(" ORDER BY ST_Distance(CAST(sv.location AS geography), CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography))");
        queryBuilder.append(" LIMIT :limit OFFSET :offset");

        Query nativeQuery = entityManager.createNativeQuery(queryBuilder.toString());
        nativeQuery.setParameter("lat", lat);
        nativeQuery.setParameter("lng", lng);
        nativeQuery.setParameter("radiusMeters", radiusMeters);
        if (minPowerKw != null) {
            nativeQuery.setParameter("minPowerKw", minPowerKw);
        }
        nativeQuery.setParameter("limit", pageable.getPageSize());
        nativeQuery.setParameter("offset", pageable.getOffset());

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        // Map to DTOs
        List<StationListItemDTO> stations = new ArrayList<>();
        for (Object[] row : results) {
            UUID stationId = (UUID) row[0];
            String name = (String) row[1];
            String address = (String) row[2];
            Double stationLat = ((Number) row[3]).doubleValue();
            Double stationLng = ((Number) row[4]).doubleValue();
            String operatingHours = (String) row[5];
            String parking = (String) row[6];
            String visibility = (String) row[7];
            String publicStatus = (String) row[8];

            // Fetch charging summary
            ChargingSummaryDTO chargingSummary = getChargingSummaryForStationVersion(stationId);
            
            // Get real trust score, default to 50 if not calculated yet
            Integer trustScore = trustRepository.findById(stationId)
                    .map(trust -> trust.getScore())
                    .orElse(50);

            stations.add(StationListItemDTO.builder()
                    .stationId(stationId.toString())
                    .name(name)
                    .address(address)
                    .lat(stationLat)
                    .lng(stationLng)
                    .operatingHours(operatingHours)
                    .parking(parking)
                    .visibility(visibility)
                    .publicStatus(publicStatus)
                    .chargingSummary(chargingSummary)
                    .trustScore(trustScore)
                    .build());
        }

        return new PageImpl<>(stations, pageable, total);
    }

    @Override
    public Optional<StationDetailDTO> findPublishedStationDetail(UUID stationId) {
        String query = """
            SELECT 
                sv.station_id,
                sv.name,
                sv.address,
                ST_Y(CAST(sv.location AS geometry)) as lat,
                ST_X(CAST(sv.location AS geometry)) as lng,
                sv.operating_hours,
                sv.parking,
                sv.visibility,
                sv.public_status,
                sv.published_at
            FROM station_version sv
            WHERE sv.station_id = :stationId
            AND sv.workflow_status = 'PUBLISHED'
            """;

        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("stationId", stationId);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        if (results.isEmpty()) {
            return Optional.empty();
        }

        Object[] row = results.get(0);
        UUID foundStationId = (UUID) row[0];
        String name = (String) row[1];
        String address = (String) row[2];
        Double lat = ((Number) row[3]).doubleValue();
        Double lng = ((Number) row[4]).doubleValue();
        String operatingHours = (String) row[5];
        String parking = (String) row[6];
        String visibility = (String) row[7];
        String publicStatus = (String) row[8];
        java.time.Instant publishedAt = row[9] != null ? 
            ((java.sql.Timestamp) row[9]).toInstant() : null;

        // Fetch charging ports
        List<PortInfoDTO> ports = getChargingPortsForStation(stationId);
        
        // Get real trust score, default to 50 if not calculated yet
        Integer trustScore = trustRepository.findById(stationId)
                .map(trust -> trust.getScore())
                .orElse(50);

        return Optional.of(StationDetailDTO.builder()
                .stationId(foundStationId.toString())
                .name(name)
                .address(address)
                .lat(lat)
                .lng(lng)
                .operatingHours(operatingHours)
                .parking(parking)
                .visibility(visibility)
                .publicStatus(publicStatus)
                .publishedAt(publishedAt)
                .ports(ports)
                .trustScore(trustScore)
                .build());
    }

    private ChargingSummaryDTO getChargingSummaryForStationVersion(UUID stationId) {
        String query = """
            SELECT 
                cp.power_type,
                cp.power_kw,
                cp.port_count
            FROM station_version sv
            JOIN station_service ss ON sv.id = ss.station_version_id
            JOIN charging_port cp ON ss.id = cp.station_service_id
            WHERE sv.station_id = :stationId
            AND sv.workflow_status = 'PUBLISHED'
            ORDER BY cp.power_type, cp.power_kw DESC NULLS LAST
            """;

        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("stationId", stationId);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        List<PortInfoDTO> ports = new ArrayList<>();
        int totalPorts = 0;
        BigDecimal maxPowerKw = null;

        for (Object[] row : results) {
            String powerType = (String) row[0];
            BigDecimal powerKw = row[1] != null ? (BigDecimal) row[1] : null;
            Integer portCount = ((Number) row[2]).intValue();

            ports.add(PortInfoDTO.builder()
                    .powerType(powerType)
                    .powerKw(powerKw)
                    .count(portCount)
                    .build());

            totalPorts += portCount;

            // Track max DC power
            if (PowerType.DC.name().equals(powerType) && powerKw != null) {
                if (maxPowerKw == null || powerKw.compareTo(maxPowerKw) > 0) {
                    maxPowerKw = powerKw;
                }
            }
        }

        return ChargingSummaryDTO.builder()
                .totalPorts(totalPorts)
                .maxPowerKw(maxPowerKw)
                .ports(ports)
                .build();
    }

    private List<PortInfoDTO> getChargingPortsForStation(UUID stationId) {
        String query = """
            SELECT 
                cp.power_type,
                cp.power_kw,
                cp.port_count
            FROM station_version sv
            JOIN station_service ss ON sv.id = ss.station_version_id
            JOIN charging_port cp ON ss.id = cp.station_service_id
            WHERE sv.station_id = :stationId
            AND sv.workflow_status = 'PUBLISHED'
            ORDER BY cp.power_type, cp.power_kw DESC NULLS LAST
            """;

        Query nativeQuery = entityManager.createNativeQuery(query);
        nativeQuery.setParameter("stationId", stationId);

        @SuppressWarnings("unchecked")
        List<Object[]> results = nativeQuery.getResultList();

        return results.stream()
                .map(row -> PortInfoDTO.builder()
                        .powerType((String) row[0])
                        .powerKw(row[1] != null ? (BigDecimal) row[1] : null)
                        .count(((Number) row[2]).intValue())
                        .build())
                .collect(Collectors.toList());
    }
}

