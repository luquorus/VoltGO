package com.example.evstation.station.application;

import com.example.evstation.api.ev_user_mobile.dto.StationDetailDTO;
import com.example.evstation.api.ev_user_mobile.dto.StationListItemDTO;
import com.example.evstation.station.application.port.StationQueryRepository;
import lombok.RequiredArgsConstructor;
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
    public Optional<StationDetailDTO> findStationDetail(UUID stationId) {
        return queryRepository.findPublishedStationDetail(stationId);
    }
}

