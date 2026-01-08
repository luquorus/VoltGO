package com.example.evstation.trust.infrastructure.jpa;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface StationTrustJpaRepository extends JpaRepository<StationTrustEntity, UUID> {
    // stationId is the primary key, so findById works directly
}

