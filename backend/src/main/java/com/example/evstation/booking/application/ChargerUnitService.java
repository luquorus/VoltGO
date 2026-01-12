package com.example.evstation.booking.application;

import com.example.evstation.api.ev_user_mobile.dto.ChargerUnitDTO;
import com.example.evstation.booking.domain.ChargerUnitStatus;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitEntity;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChargerUnitService {
    
    private final ChargerUnitJpaRepository chargerUnitRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    
    /**
     * Get all active charger units for a station
     */
    @Transactional(readOnly = true)
    public List<ChargerUnitDTO> getChargerUnits(UUID stationId) {
        log.debug("Getting charger units for station: {}", stationId);
        
        // Validate station has published version
        boolean stationPublished = stationVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED)
                .isPresent();
        
        if (!stationPublished) {
            throw new BusinessException(ErrorCode.NOT_FOUND, 
                    "Station not found or does not have a published version");
        }
        
        List<ChargerUnitEntity> entities = chargerUnitRepository
                .findByStationIdAndStatusOrderByLabel(stationId, ChargerUnitStatus.ACTIVE);
        
        return entities.stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }
    
    /**
     * Get charger unit by ID and validate it belongs to station
     */
    @Transactional(readOnly = true)
    public ChargerUnitEntity getChargerUnitByIdAndStation(UUID chargerUnitId, UUID stationId) {
        return chargerUnitRepository.findByIdAndStationId(chargerUnitId, stationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.CHARGER_UNIT_NOT_FOUND,
                        "Charger unit not found or does not belong to station"));
    }
    
    private ChargerUnitDTO toDTO(ChargerUnitEntity entity) {
        return ChargerUnitDTO.builder()
                .id(entity.getId())
                .stationId(entity.getStationId())
                .label(entity.getLabel())
                .powerType(entity.getPowerType().name())
                .powerKw(entity.getPowerKw())
                .pricePerSlot(entity.getPricePerSlot())
                .status(entity.getStatus().name())
                .build();
    }
}

