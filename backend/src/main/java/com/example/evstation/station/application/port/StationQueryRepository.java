package com.example.evstation.station.application.port;

import com.example.evstation.api.ev_user_mobile.dto.PolylinePoint;
import com.example.evstation.api.ev_user_mobile.dto.RecommendedStationDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationListItemDTO;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.util.List;
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

    /**
     * Search published stations by name (case-insensitive, partial match)
     * @param nameQuery Search query for station name
     * @param pageable Pagination
     * @return Page of StationListItemDTO
     */
    Page<StationListItemDTO> searchPublishedStationsByName(
            String nameQuery,
            Pageable pageable
    );

    /**
     * Find stations along a route corridor (within buffer distance of route polyline)
     * @param routeWkt WKT LINESTRING representation of the route
     * @param bufferMeters Buffer distance in meters around the route
     * @param minPowerKw Optional: filter DC ports with power_kw >= minPowerKw
     * @param limit Maximum number of stations to return
     * @param polyline List of polyline points for distance calculations
     * @param batteryPercent Current battery percentage (0-100)
     * @param vehicleRangeKm Range at 100% battery (km)
     * @param routeDistanceKm Total route distance (km)
     * @param traceId Trace ID for diagnostic logging
     * @return List of RecommendedStationDTO sorted by score (lower is better)
     */
    List<RecommendedStationDTO> findStationsAlongRoute(
            String routeWkt,
            double bufferMeters,
            Double minPowerKw,
            int limit,
            List<PolylinePoint> polyline,
            Integer batteryPercent,
            Double vehicleRangeKm,
            Double routeDistanceKm,
            String traceId
    );
}

