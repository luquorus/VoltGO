package com.example.evstation.risk.application;

import com.example.evstation.risk.domain.RiskAssessment;
import com.example.evstation.risk.domain.RiskReasonCode;
import com.example.evstation.station.domain.ChangeRequestType;
import com.example.evstation.station.domain.ServiceType;
import com.example.evstation.station.infrastructure.jpa.ChangeRequestEntity;
import com.example.evstation.station.infrastructure.jpa.ChargingPortJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationServiceEntity;
import com.example.evstation.station.infrastructure.jpa.StationServiceJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RiskEngineServiceTest {

    @Mock
    StationVersionJpaRepository stationVersionRepository;
    @Mock
    StationServiceJpaRepository stationServiceRepository;
    @Mock
    ChargingPortJpaRepository chargingPortRepository;

    @InjectMocks
    RiskEngineService riskEngineService;

    @Test
    void assessChangeRequest_createStation_lowSwapInventoryAddsReason() {
        UUID proposedVersionId = UUID.randomUUID();

        ChangeRequestEntity cr = ChangeRequestEntity.builder()
                .id(UUID.randomUUID())
                .type(ChangeRequestType.CREATE_STATION)
                .proposedStationVersionId(proposedVersionId)
                .build();

        StationVersionEntity version = mock(StationVersionEntity.class);
        when(version.getId()).thenReturn(proposedVersionId);

        StationServiceEntity swap = StationServiceEntity.builder()
                .id(UUID.randomUUID())
                .stationVersionId(proposedVersionId)
                .serviceType(ServiceType.BATTERY_SWAP)
                .totalBatteries(3)
                .avgChargePowerKw(new BigDecimal("35"))
                .build();

        when(stationVersionRepository.findById(proposedVersionId)).thenReturn(Optional.of(version));
        when(stationServiceRepository.findByStationVersionId(proposedVersionId)).thenReturn(List.of(swap));
        when(chargingPortRepository.findByStationServiceIds(any())).thenReturn(List.of());

        RiskAssessment assessment = riskEngineService.assessChangeRequest(cr);

        assertThat(assessment.getRiskReasons()).contains(RiskReasonCode.NEW_STATION);
        assertThat(assessment.getRiskReasons()).contains(RiskReasonCode.SWAP_LOW_INVENTORY);
    }
}
