package com.example.evstation.booking.application;

import com.example.evstation.booking.domain.ChargerUnitStatus;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitEntity;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitJpaRepository;
import com.example.evstation.station.domain.PowerType;
import com.example.evstation.station.infrastructure.jpa.ChargingPortEntity;
import com.example.evstation.station.infrastructure.jpa.ChargingPortJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationServiceEntity;
import com.example.evstation.station.infrastructure.jpa.StationServiceJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Service to automatically create charger units from charging ports when a station is published.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ChargerUnitCreationService {
    
    private final ChargerUnitJpaRepository chargerUnitRepository;
    private final StationServiceJpaRepository stationServiceRepository;
    private final ChargingPortJpaRepository chargingPortRepository;
    
    /**
     * Create charger units from charging ports for a published station version.
     * This is called automatically when a station version is published.
     * 
     * @param stationVersion The published station version
     * @return List of created charger unit IDs
     */
    @Transactional
    public List<UUID> createChargerUnitsFromChargingPorts(StationVersionEntity stationVersion) {
        UUID stationId = stationVersion.getStationId();
        UUID stationVersionId = stationVersion.getId();
        
        log.info("Creating charger units from charging ports: stationId={}, stationVersionId={}", 
                stationId, stationVersionId);
        
        // Check if charger units already exist for this station version
        List<ChargerUnitEntity> existingUnits = chargerUnitRepository
                .findByStationIdOrderByLabel(stationId);
        
        boolean unitsExist = existingUnits.stream()
                .anyMatch(cu -> cu.getStationVersionId().equals(stationVersionId));
        
        if (unitsExist) {
            log.info("Charger units already exist for station version: {} (found {} units)", 
                    stationVersionId, existingUnits.size());
            return existingUnits.stream()
                    .filter(cu -> cu.getStationVersionId().equals(stationVersionId))
                    .map(ChargerUnitEntity::getId)
                    .toList();
        }
        
        // Get all services for this station version
        List<StationServiceEntity> services = stationServiceRepository
                .findByStationVersionId(stationVersionId);
        
        if (services.isEmpty()) {
            log.warn("No services found for station version: {}", stationVersionId);
            return List.of();
        }
        
        List<UUID> createdUnitIds = new ArrayList<>();
        
        // For each service, get charging ports and create charger units
        for (StationServiceEntity service : services) {
            List<ChargingPortEntity> ports = chargingPortRepository
                    .findByStationServiceId(service.getId());
            
            for (ChargingPortEntity port : ports) {
                // Create port_count number of charger units for this port
                int portCount = port.getPortCount();
                
                for (int unitNum = 1; unitNum <= portCount; unitNum++) {
                    String label = generateLabel(port.getPowerType(), port.getPowerKw(), unitNum);
                    
                    // Check if charger unit with this label already exists for this station
                    // Use existingUnits list we already loaded to avoid multiple queries
                    boolean labelExists = existingUnits.stream()
                            .anyMatch(cu -> cu.getLabel().equals(label));
                    
                    if (labelExists) {
                        log.debug("Charger unit with label {} already exists for station {}, skipping", 
                                label, stationId);
                        continue;
                    }
                    
                    // Calculate price per slot (30 minutes)
                    int pricePerSlot = calculatePricePerSlot(port.getPowerType(), port.getPowerKw());
                    
                    // Create charger unit
                    ChargerUnitEntity chargerUnit = ChargerUnitEntity.builder()
                            .id(UUID.randomUUID())
                            .stationId(stationId)
                            .stationVersionId(stationVersionId)
                            .powerType(port.getPowerType())
                            .powerKw(port.getPowerKw())
                            .label(label)
                            .pricePerSlot(pricePerSlot)
                            .status(ChargerUnitStatus.ACTIVE)
                            .createdAt(Instant.now())
                            .build();
                    
                    chargerUnitRepository.save(chargerUnit);
                    createdUnitIds.add(chargerUnit.getId());
                    
                    log.debug("Created charger unit: id={}, label={}, pricePerSlot={}", 
                            chargerUnit.getId(), label, pricePerSlot);
                }
            }
        }
        
        log.info("Created {} charger units for station version: {}", createdUnitIds.size(), stationVersionId);
        return createdUnitIds;
    }
    
    /**
     * Generate label for charger unit based on power type and power KW.
     * Examples: DC250-01, DC120-01, AC-01
     */
    private String generateLabel(PowerType powerType, BigDecimal powerKw, int unitNum) {
        if (powerType == PowerType.DC && powerKw != null) {
            int powerKwInt = powerKw.intValue();
            return String.format("DC%d-%02d", powerKwInt, unitNum);
        } else {
            return String.format("AC-%02d", unitNum);
        }
    }
    
    /**
     * Calculate price per slot (30 minutes) based on power type and power KW.
     */
    private int calculatePricePerSlot(PowerType powerType, BigDecimal powerKw) {
        if (powerType == PowerType.DC && powerKw != null) {
            int powerKwInt = powerKw.intValue();
            if (powerKwInt >= 200) {
                return 30000; // 250kW DC: 30k VND/slot
            } else if (powerKwInt >= 100) {
                return 20000; // 120kW DC: 20k VND/slot
            } else {
                return 15000; // Other DC: 15k VND/slot
            }
        } else {
            return 10000; // AC: 10k VND/slot
        }
    }
}

