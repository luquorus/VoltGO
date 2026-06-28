package com.example.evstation.station.application;

import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationListItemDTO;
import com.example.evstation.common.config.CacheNames;
import com.example.evstation.station.application.port.StationQueryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

/**
 * Query Service for read-only operations (CQRS pattern)
 * Only queries PUBLISHED station versions
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StationQueryService {
    
    private final StationQueryRepository queryRepository;

    /**
     * Find published stations within radius
     */
    @Cacheable(
            value = CacheNames.STATION_RADIUS,
            key = "T(java.lang.String).format('%.4f:%.4f:%s:%s:%s:%d:%d',"
                    + " #lat, #lng, #radiusKm, "
                    + " T(java.util.Objects).toString(#minPowerKw,'null'), "
                    + " T(java.util.Objects).toString(#hasAC,'null'), "
                    + " #pageable.pageNumber, #pageable.pageSize)"
    )
    public Page<StationListItemDTO> findStationsWithinRadius(
            double lat,
            double lng,
            double radiusKm,
            BigDecimal minPowerKw,
            Boolean hasAC,
            Pageable pageable) {
        
        return queryRepository.findPublishedStationsWithinRadius(
                lat, lng, radiusKm, minPowerKw, hasAC, pageable
        );
    }

    /**
     * Find published station detail by station ID
     */
    @Cacheable(value = CacheNames.STATION_DETAIL, key = "#stationId")
    public Optional<StationDetailDTO> findStationDetail(UUID stationId) {
        return queryRepository.findPublishedStationDetail(stationId);
    }

    /**
     * Search published stations by name
     */
    @Cacheable(
            value = CacheNames.STATION_SEARCH,
            key = "#nameQuery + ':' + #pageable.pageNumber + ':' + #pageable.pageSize"
    )
    public Page<StationListItemDTO> searchStationsByName(
            String nameQuery,
            Pageable pageable) {
        return queryRepository.searchPublishedStationsByName(nameQuery, pageable);
    }
}

