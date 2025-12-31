package com.example.evstation.station.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface StationServiceJpaRepository extends JpaRepository<StationServiceEntity, UUID> {
    List<StationServiceEntity> findByStationVersionId(UUID stationVersionId);
}

