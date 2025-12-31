package com.example.evstation.station.domain;

import java.time.Instant;
import java.util.UUID;

public class Station {
    private final UUID id;
    private final UUID providerId;
    private final Instant createdAt;

    public Station(UUID id, UUID providerId, Instant createdAt) {
        this.id = id;
        this.providerId = providerId;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getProviderId() {
        return providerId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}

