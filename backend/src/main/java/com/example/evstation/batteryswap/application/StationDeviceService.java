package com.example.evstation.batteryswap.application;

import com.example.evstation.batteryswap.infrastructure.jpa.StationDeviceEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.StationDeviceJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class StationDeviceService {

    private final StationDeviceJpaRepository stationDeviceRepository;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public String getOrCreateDeviceKey(UUID stationId, String deviceName) {
        Optional<StationDeviceEntity> existing = stationDeviceRepository.findById(stationId);
        if (existing.isPresent()) {
            StationDeviceEntity device = existing.get();
            device.setLastSeenAt(Instant.now());
            stationDeviceRepository.save(device);
            log.debug("[Device] Returning existing key for station {}", stationId);
            return device.getDeviceKey();
        }

        String deviceKey = generateDeviceKey();
        StationDeviceEntity device = StationDeviceEntity.builder()
                .stationId(stationId)
                .deviceKey(deviceKey)
                .deviceName(deviceName != null ? deviceName : "Simulator-" + stationId.toString().substring(0, 8))
                .createdAt(Instant.now())
                .lastSeenAt(Instant.now())
                .build();
        stationDeviceRepository.save(device);
        log.info("[Device] Created new device key for station {}: {}", stationId, deviceKey);
        return deviceKey;
    }

    @Transactional(readOnly = true)
    public Optional<UUID> validateDeviceKey(String deviceKey) {
        if (deviceKey == null || deviceKey.isBlank()) {
            return Optional.empty();
        }
        return stationDeviceRepository.findByDeviceKey(deviceKey)
                .map(StationDeviceEntity::getStationId);
    }

    private String generateDeviceKey() {
        byte[] bytes = new byte[24];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
