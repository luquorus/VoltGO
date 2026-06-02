package com.example.evstation.batteryswap.infrastructure.mapper;

import com.example.evstation.auth.infrastructure.jpa.UserAccountJpaRepository;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapCRListDTO;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapChangeRequestEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapPileTemplateEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapSlotTemplateEntity;
import com.example.evstation.batteryswap.infrastructure.jpa.BatterySwapStationVersionEntity;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.stream.Collectors;

@Component
public class BatterySwapVersionMapper {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final UserAccountJpaRepository userRepository;
    private final StationVersionJpaRepository stationVersionRepository;

    @Autowired
    public BatterySwapVersionMapper(
            UserAccountJpaRepository userRepository,
            StationVersionJpaRepository stationVersionRepository) {
        this.userRepository = userRepository;
        this.stationVersionRepository = stationVersionRepository;
    }

    public BatterySwapCRDTO toDTO(BatterySwapChangeRequestEntity cr, BatterySwapStationVersionEntity version) {
        List<BatterySwapCRDTO.PileDTO> pileDTOs = toPileDTOs(version);

        String submittedByEmail = cr.getSubmittedBy() != null
                ? userRepository.findById(cr.getSubmittedBy()).map(user -> user.getEmail()).orElse(null)
                : null;

        String stationName = resolveStationName(cr.getStationId());

        return BatterySwapCRDTO.builder()
                .id(cr.getId())
                .type(cr.getType())
                .status(cr.getStatus())
                .stationId(cr.getStationId())
                .stationName(stationName)
                .submittedBy(cr.getSubmittedBy())
                .submittedByEmail(submittedByEmail)
                .riskScore(cr.getRiskScore())
                .riskReasons(parseRiskReasons(cr.getRiskReasons()))
                .adminNote(cr.getAdminNote())
                .createdAt(cr.getCreatedAt())
                .submittedAt(cr.getSubmittedAt())
                .decidedAt(cr.getDecidedAt())
                .versionId(version != null ? version.getId() : null)
                .versionNo(version != null ? version.getVersionNo() : null)
                .workflowStatus(version != null ? version.getWorkflowStatus() : null)
                .totalBatteries(version != null ? version.getTotalBatteries() : null)
                .avgChargePowerKw(version != null ? version.getAvgChargePowerKw() : null)
                .operatingHours(version != null ? version.getOperatingHours() : null)
                .parkingFee(version != null ? version.getParkingFee() : null)
                .note(version != null ? version.getNote() : null)
                .publishedAt(version != null ? version.getPublishedAt() : null)
                .pileTemplates(pileDTOs)
                .requiresVerification(cr.getRiskScore() != null && cr.getRiskScore() >= 20)
                .requiresAdminReview(cr.getRiskScore() != null && cr.getRiskScore() >= 50)
                .build();
    }

    public BatterySwapCRDTO toDTO(BatterySwapChangeRequestEntity cr) {
        return toDTO(cr, cr.getProposedVersion());
    }

    public BatterySwapCRListDTO toListDTO(BatterySwapChangeRequestEntity cr) {
        String stationName = resolveStationName(cr.getStationId());

        String submittedByEmail = cr.getSubmittedBy() != null
                ? userRepository.findById(cr.getSubmittedBy()).map(user -> user.getEmail()).orElse(null)
                : null;

        return BatterySwapCRListDTO.builder()
                .id(cr.getId())
                .type(cr.getType())
                .status(cr.getStatus())
                .stationId(cr.getStationId())
                .stationName(stationName)
                .riskScore(cr.getRiskScore())
                .createdAt(cr.getCreatedAt())
                .submittedAt(cr.getSubmittedAt())
                .submittedBy(cr.getSubmittedBy())
                .submittedByEmail(submittedByEmail)
                .build();
    }

    public BatterySwapCRDTO toDTOWithoutVersion(BatterySwapChangeRequestEntity cr) {
        String submittedByEmail = cr.getSubmittedBy() != null
                ? userRepository.findById(cr.getSubmittedBy()).map(user -> user.getEmail()).orElse(null)
                : null;
        String stationName = resolveStationName(cr.getStationId());
        return BatterySwapCRDTO.builder()
                .id(cr.getId())
                .type(cr.getType())
                .status(cr.getStatus())
                .stationId(cr.getStationId())
                .stationName(stationName)
                .submittedBy(cr.getSubmittedBy())
                .submittedByEmail(submittedByEmail)
                .riskScore(cr.getRiskScore())
                .riskReasons(parseRiskReasons(cr.getRiskReasons()))
                .adminNote(cr.getAdminNote())
                .createdAt(cr.getCreatedAt())
                .submittedAt(cr.getSubmittedAt())
                .decidedAt(cr.getDecidedAt())
                .requiresVerification(cr.getRiskScore() != null && cr.getRiskScore() >= 20)
                .requiresAdminReview(cr.getRiskScore() != null && cr.getRiskScore() >= 50)
                .build();
    }

    private String resolveStationName(java.util.UUID stationId) {
        if (stationId == null) {
            return null;
        }
        return stationVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED)
                .map(sv -> sv.getName())
                .orElse("Station-" + stationId.toString().substring(0, 8));
    }

    private List<BatterySwapCRDTO.PileDTO> toPileDTOs(BatterySwapStationVersionEntity version) {
        if (version == null || version.getPileTemplates() == null) {
            return List.of();
        }
        return version.getPileTemplates().stream()
                .sorted((a, b) -> Integer.compare(a.getPileIndex(), b.getPileIndex()))
                .map(this::toPileDTO)
                .collect(Collectors.toList());
    }

    private BatterySwapCRDTO.PileDTO toPileDTO(BatterySwapPileTemplateEntity pile) {
        List<BatterySwapCRDTO.SlotDTO> slotDTOs = pile.getSlotTemplates() != null
                ? pile.getSlotTemplates().stream()
                        .sorted((a, b) -> Integer.compare(a.getSlotIndex(), b.getSlotIndex()))
                        .map(this::toSlotDTO)
                        .collect(Collectors.toList())
                : List.of();

        return BatterySwapCRDTO.PileDTO.builder()
                .id(pile.getId())
                .pileIndex(pile.getPileIndex())
                .slotsPerPile(pile.getSlotsPerPile())
                .slots(slotDTOs)
                .build();
    }

    private BatterySwapCRDTO.SlotDTO toSlotDTO(BatterySwapSlotTemplateEntity slot) {
        return BatterySwapCRDTO.SlotDTO.builder()
                .id(slot.getId())
                .slotIndex(slot.getSlotIndex())
                .batteryCapacityKwh(slot.getBatteryCapacityKwh())
                .build();
    }

    private List<String> parseRiskReasons(String riskReasons) {
        if (riskReasons == null || riskReasons.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(riskReasons, new TypeReference<List<String>>() {});
        } catch (JsonProcessingException e) {
            return List.of();
        }
    }
}
