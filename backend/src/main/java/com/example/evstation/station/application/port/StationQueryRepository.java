package com.example.evstation.station.application.port;

import com.example.evstation.api.ev_user_mobile.dto.StationListItemDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

/**
 * Query Repository for read-only operations (CQRS pattern)
 * Only queries PUBLISHED station versions
 */
public interface StationQueryRepository {
    
    /**
     * Find published stations within radius
     * @param lat Latitude
     * @param lng Longitude
     * @param radiusKm Radius in kilometers
     * @param minPowerKw Optional: filter DC ports with power_kw >= minPowerKw
     * @param hasAC Optional: filter stations that have AC ports
     * @param pageable Pagination
     * @return Page of StationListItemDTO
     */
    Page<StationListItemDTO> findPublishedStationsWithinRadius(
            double lat,
            double lng,
            double radiusKm,
            BigDecimal minPowerKw,
            Boolean hasAC,
            Pageable pageable
    );

    /**
     * Find published station detail by station ID
     * @param stationId Station ID
     * @return StationDetailDTO or empty if not found or not published
     */
    Optional<StationDetailDTO> findPublishedStationDetail(UUID stationId);
}

