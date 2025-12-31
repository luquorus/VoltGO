package com.example.evstation.station.domain;

import java.math.BigDecimal;
import java.util.UUID;

public class ChargingPort {
    private final UUID id;
    private final UUID stationServiceId;
    private final PowerType powerType;
    private final BigDecimal powerKw;
    private final int portCount;

    public ChargingPort(UUID id, UUID stationServiceId, PowerType powerType, BigDecimal powerKw, int portCount) {
        this.id = id;
        this.stationServiceId = stationServiceId;
        this.powerType = powerType;
        this.powerKw = powerKw;
        this.portCount = portCount;
    }

    public UUID getId() {
        return id;
    }

    public UUID getStationServiceId() {
        return stationServiceId;
    }

    public PowerType getPowerType() {
        return powerType;
    }

    public BigDecimal getPowerKw() {
        return powerKw;
    }

    public int getPortCount() {
        return portCount;
    }
}

