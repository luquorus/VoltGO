package com.example.evstation.batteryswap.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SwapPileJpaRepository extends JpaRepository<SwapPileEntity, UUID> {

    List<SwapPileEntity> findByStationIdOrderByPileIndexAsc(UUID stationId);

    Optional<SwapPileEntity> findByStationIdAndPileIndex(UUID stationId, Integer pileIndex);

    int countByStationId(UUID stationId);

    void deleteByStationId(UUID stationId);
}
