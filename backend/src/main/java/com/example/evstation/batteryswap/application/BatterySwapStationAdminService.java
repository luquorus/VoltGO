package com.example.evstation.batteryswap.application;

import com.example.evstation.common.web.PaginationResponse;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationDetailDTO;
import com.example.evstation.batteryswap.api.dto.BatterySwapStationListDTO;
import com.example.evstation.batteryswap.api.dto.UpdateBatterySwapStationDTO;
import com.example.evstation.batteryswap.domain.ChangeRequestStatus;
import com.example.evstation.batteryswap.infrastructure.jpa.*;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class BatterySwapStationAdminService {

    private static final int SRID = 4326;
    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory(new PrecisionModel(), SRID);

    private final StationJpaRepository stationRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    private final BatterySwapStationVersionJpaRepository bsVersionRepository;
    private final BatterySwapStationStateJpaRepository stateRepository;
    private final SwapPileJpaRepository pileRepository;
    private final BatterySwapChangeRequestJpaRepository crRepository;
    private final BatterySwapTrustJpaRepository trustRepository;
    private final BatterySwapPileTemplateJpaRepository pileTemplateRepository;
    private final SwapStationStateApplyService swapStationStateApplyService;

    @Transactional(readOnly = true)
    public PaginationResponse<BatterySwapStationListDTO> listStations(int page, int size, String search) {
        log.info("Admin listing battery swap stations: page={}, size={}, search={}", page, size, search);

        List<UUID> bsStationIds = bsVersionRepository.findAll().stream()
                .map(BatterySwapStationVersionEntity::getStationId)
                .distinct()
                .toList();

        List<StationEntity> bsStations = stationRepository.findAll().stream()
                .filter(s -> bsStationIds.contains(s.getId()))
                .filter(s -> {
                    if (search == null || search.isBlank()) {
                        return true;
                    }
                    String searchLower = search.trim().toLowerCase();
                    boolean matchesId = s.getId().toString().toLowerCase().contains(searchLower);
                    var publishedVersion = stationVersionRepository
                            .findByStationIdAndWorkflowStatus(s.getId(), WorkflowStatus.PUBLISHED)
                            .orElse(null);
                    boolean matchesName = publishedVersion != null
                            && publishedVersion.getName() != null
                            && publishedVersion.getName().toLowerCase().contains(searchLower);
                    return matchesId || matchesName;
                })
                .toList();

        int total = bsStations.size();
        int fromIndex = page * size;
        int toIndex = Math.min(fromIndex + size, total);

        List<BatterySwapStationListDTO> content;
        if (fromIndex >= total) {
            content = List.of();
        } else {
            content = bsStations.subList(fromIndex, toIndex).stream()
                    .map(this::buildListDTO)
                    .toList();
        }

        return PaginationResponse.<BatterySwapStationListDTO>builder()
                .content(content)
                .totalElements(total)
                .totalPages((int) Math.ceil((double) total / size))
                .size(size)
                .page(page)
                .first(page == 0)
                .last(toIndex >= total)
                .build();
    }

    @Transactional(readOnly = true)
    public Optional<BatterySwapStationDetailDTO> getStation(UUID stationId) {
        return getStationWithVersion(stationId, null);
    }

    /**
     * Get station detail, optionally scoped to a specific version.
     */
    @Transactional(readOnly = true)
    public Optional<BatterySwapStationDetailDTO> getStationWithVersion(UUID stationId, UUID specificVersionId) {
        log.info("Admin getting battery swap station detail: {} (version={})", stationId, specificVersionId);

        StationEntity station = stationRepository.findById(stationId).orElse(null);
        if (station == null) {
            return Optional.empty();
        }

        if (!hasBatterySwapServiceForStation(stationId)) {
            return Optional.empty();
        }

        return Optional.of(buildDetailDTO(station, specificVersionId));
    }

    private boolean hasBatterySwapServiceForStation(UUID stationId) {
        return !bsVersionRepository.findByStationIdOrderByVersionNoDesc(stationId).isEmpty();
    }

    private BatterySwapStationDetailDTO buildDetailDTO(StationEntity station, UUID specificVersionId) {
        UUID stationId = station.getId();
        var listDTO = buildListDTO(station);

        var bsVersion = specificVersionId != null
                ? bsVersionRepository.findById(specificVersionId).orElse(null)
                : bsVersionRepository.findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED).orElse(null);

        var stationVersion = specificVersionId != null
                ? stationVersionRepository.findById(specificVersionId).orElse(null)
                : stationVersionRepository.findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED).orElse(null);

        List<BatterySwapStationDetailDTO.PileTemplateDTO> pileTemplates = List.of();
        if (bsVersion != null) {
            var templates = pileTemplateRepository.findByStationVersionIdOrderByPileIndex(bsVersion.getId());
            pileTemplates = templates.stream()
                    .map(t -> BatterySwapStationDetailDTO.PileTemplateDTO.builder()
                            .id(t.getId().toString())
                            .pileIndex(t.getPileIndex())
                            .slotsPerPile(t.getSlotsPerPile())
                            .slots(List.of())
                            .build())
                    .toList();
        }

        return BatterySwapStationDetailDTO.builder()
                .id(listDTO.getId())
                .providerId(listDTO.getProviderId())
                .stationCreatedAt(listDTO.getStationCreatedAt())
                .publishedVersionId(listDTO.getPublishedVersionId())
                .publishedVersionNo(listDTO.getPublishedVersionNo())
                .name(stationVersion != null ? stationVersion.getName() : listDTO.getName())
                .address(stationVersion != null ? stationVersion.getAddress() : listDTO.getAddress())
                .lat(stationVersion != null && stationVersion.getLocation() != null
                        ? stationVersion.getLocation().getY() : listDTO.getLat())
                .lng(stationVersion != null && stationVersion.getLocation() != null
                        ? stationVersion.getLocation().getX() : listDTO.getLng())
                .operatingHours(bsVersion != null ? bsVersion.getOperatingHours() : listDTO.getOperatingHours())
                .workflowStatus(bsVersion != null ? bsVersion.getWorkflowStatus().name() : listDTO.getWorkflowStatus())
                .publishedAt(listDTO.getPublishedAt())
                .createdBy(listDTO.getCreatedBy())
                .totalBatteries(bsVersion != null ? bsVersion.getTotalBatteries() : listDTO.getTotalBatteries())
                .availableBatteries(listDTO.getAvailableBatteries())
                .avgChargePowerKw(bsVersion != null ? bsVersion.getAvgChargePowerKw() : listDTO.getAvgChargePowerKw())
                .parkingFee(bsVersion != null && bsVersion.getParkingFee() != null
                        ? bsVersion.getParkingFee().toString() : listDTO.getParkingFee())
                .totalPiles(listDTO.getTotalPiles())
                .totalSlots(bsVersion != null ? bsVersion.getTotalSlotCount() : listDTO.getTotalSlots())
                .trustScore(listDTO.getTrustScore())
                .trustLevel(listDTO.getTrustLevel())
                .totalVersions(listDTO.getTotalVersions())
                .pendingCRs(listDTO.getPendingCRs())
                .pileTemplates(pileTemplates)
                .note(bsVersion != null ? bsVersion.getNote() : null)
                .build();
    }

    private BatterySwapStationListDTO buildListDTO(StationEntity station) {
        UUID stationId = station.getId();

        var publishedVersion = stationVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED)
                .orElse(null);

        var bsVersion = bsVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED)
                .orElse(null);

        var state = stateRepository.findById(stationId).orElse(null);

        int pileCount = pileRepository.countByStationId(stationId);
        long pendingCRs = crRepository.countByStationIdAndStatus(stationId, ChangeRequestStatus.PENDING);
        long totalVersions = bsVersionRepository.countByStationId(stationId);
        var trustOpt = trustRepository.findByStationId(stationId);

        return BatterySwapStationListDTO.builder()
                .id(stationId.toString())
                .providerId(station.getProviderId() != null ? station.getProviderId().toString() : null)
                .stationCreatedAt(station.getCreatedAt())
                .publishedVersionId(bsVersion != null ? bsVersion.getId().toString() : null)
                .publishedVersionNo(bsVersion != null ? bsVersion.getVersionNo() : null)
                .name(publishedVersion != null ? publishedVersion.getName() : null)
                .address(publishedVersion != null ? publishedVersion.getAddress() : null)
                .lat(publishedVersion != null && publishedVersion.getLocation() != null
                        ? publishedVersion.getLocation().getY() : null)
                .lng(publishedVersion != null && publishedVersion.getLocation() != null
                        ? publishedVersion.getLocation().getX() : null)
                .operatingHours(bsVersion != null ? bsVersion.getOperatingHours() : null)
                .workflowStatus(bsVersion != null ? bsVersion.getWorkflowStatus().name() : null)
                .publishedAt(bsVersion != null ? bsVersion.getPublishedAt() : null)
                .createdBy(bsVersion != null && bsVersion.getCreatedBy() != null ? bsVersion.getCreatedBy().toString() : null)
                .totalBatteries(state != null ? state.getTotalBatteries() : (bsVersion != null ? bsVersion.getTotalBatteries() : null))
                .availableBatteries(state != null ? state.getAvailableBatteries() : null)
                .avgChargePowerKw(state != null ? state.getAvgChargePowerKw() : (bsVersion != null ? bsVersion.getAvgChargePowerKw() : null))
                .parkingFee(bsVersion != null && bsVersion.getParkingFee() != null ? bsVersion.getParkingFee().toString() : null)
                .totalPiles(pileCount)
                .totalSlots(bsVersion != null ? bsVersion.getTotalSlotCount() : null)
                .trustScore(trustOpt.map(t -> t.getScore()).orElse(null))
                .trustLevel(trustOpt.map(t -> t.getTrustLevel()).orElse(null))
                .totalVersions((int) totalVersions)
                .pendingCRs((int) pendingCRs)
                .build();
    }

    /**
     * Update a battery swap station directly (admin edit).
     * Creates a new version of the station (and station_version), optionally publishing immediately.
     * Archives the old published version if publishing a new one.
     */
    @Transactional
    public BatterySwapStationDetailDTO updateStation(UUID stationId, UpdateBatterySwapStationDTO request, UUID adminId) {
        log.info("Admin updating battery swap station: {}, publishImmediately={}",
                stationId, request.getPublishImmediately());

        StationEntity station = stationRepository.findById(stationId)
                .orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND,
                        "Station not found: " + stationId));

        UpdateBatterySwapStationDTO.StationDataDTO data = request.getStationData();

        WorkflowStatus workflowStatus = Boolean.TRUE.equals(request.getPublishImmediately())
                ? WorkflowStatus.PUBLISHED
                : WorkflowStatus.DRAFT;

        Optional<BatterySwapStationVersionEntity> currentPublished = bsVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED);
        int nextVersionNo = bsVersionRepository.findNextVersionNo(stationId);

        Point location = createPoint(data.getLocation().getLng(), data.getLocation().getLat());

        List<BatterySwapPileTemplateEntity> newPiles;
        if (data.getPileTemplates() != null && !data.getPileTemplates().isEmpty()) {
            newPiles = buildPileTemplates(data.getPileTemplates(), null);
        } else {
            newPiles = buildDefaultPileTemplates(data.getTotalBatteries(), null);
        }

        BatterySwapStationVersionEntity newBsVersion = BatterySwapStationVersionEntity.builder()
                .id(UUID.randomUUID())
                .stationId(stationId)
                .versionNo(nextVersionNo)
                .workflowStatus(workflowStatus)
                .totalBatteries(data.getTotalBatteries())
                .avgChargePowerKw(data.getAvgChargePowerKw())
                .operatingHours(data.getOperatingHours())
                .parkingFee(data.getParkingFee())
                .note(data.getNote())
                .createdBy(adminId)
                .createdAt(Instant.now())
                .publishedAt(Boolean.TRUE.equals(request.getPublishImmediately()) ? Instant.now() : null)
                .pileTemplates(new ArrayList<>())
                .build();

        for (BatterySwapPileTemplateEntity pile : newPiles) {
            pile.setStationVersion(newBsVersion);
            newBsVersion.getPileTemplates().add(pile);
        }

        bsVersionRepository.save(newBsVersion);

        // Archive old published versions BEFORE saving new ones to avoid unique constraint violations
        if (Boolean.TRUE.equals(request.getPublishImmediately())) {
            if (currentPublished.isPresent()) {
                BatterySwapStationVersionEntity old = currentPublished.get();
                old.setWorkflowStatus(WorkflowStatus.ARCHIVED);
                old.setPublishedAt(null);
                bsVersionRepository.saveAndFlush(old);
                log.info("Archived old BS version: {}", old.getId());
            }
        }

        int stationVersionNo = stationVersionRepository.findMaxVersionNoByStationId(stationId) + 1;

        StationVersionEntity newStationVersion = StationVersionEntity.builder()
                .id(newBsVersion.getId())
                .stationId(stationId)
                .versionNo(stationVersionNo)
                .workflowStatus(workflowStatus)
                .name(data.getName())
                .address(data.getAddress())
                .location(location)
                .operatingHours(data.getOperatingHours())
                .parking(com.example.evstation.station.domain.ParkingType.FREE)
                .visibility(com.example.evstation.station.domain.VisibilityType.PUBLIC)
                .publicStatus(com.example.evstation.station.domain.PublicStatus.ACTIVE)
                .createdBy(adminId)
                .createdAt(Instant.now())
                .publishedAt(Boolean.TRUE.equals(request.getPublishImmediately()) ? Instant.now() : null)
                .build();

        // Archive old station version BEFORE saving new one
        if (Boolean.TRUE.equals(request.getPublishImmediately())) {
            Optional<StationVersionEntity> currentStationPublished = stationVersionRepository
                    .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED);
            if (currentStationPublished.isPresent()) {
                StationVersionEntity old = currentStationPublished.get();
                old.setWorkflowStatus(WorkflowStatus.ARCHIVED);
                old.setPublishedAt(null);
                stationVersionRepository.saveAndFlush(old);
                log.info("Archived old station version: {}", old.getId());
            }
        }

        stationVersionRepository.saveAndFlush(newStationVersion);

        if (Boolean.TRUE.equals(request.getPublishImmediately())) {
            try {
                swapStationStateApplyService.applyForSwapVersion(newBsVersion);
            } catch (Exception e) {
                log.error("Failed to apply battery swap state for version: {}", newBsVersion.getId(), e);
            }
        }

        log.info("Battery swap station updated: stationId={}, newBsVersionId={}, status={}",
                stationId, newBsVersion.getId(), workflowStatus);

        // Build DTO from in-memory entities to avoid within-transaction visibility issues
        return buildDetailDTOFromNewVersion(station, newBsVersion, newStationVersion);
    }

    /**
     * Build detail DTO directly from in-memory new-version entities.
     * Avoids the within-transaction query visibility problem.
     */
    private BatterySwapStationDetailDTO buildDetailDTOFromNewVersion(
            StationEntity station,
            BatterySwapStationVersionEntity newBsVersion,
            StationVersionEntity newStationVersion) {
        var listDTO = buildListDTO(station);

        List<BatterySwapStationDetailDTO.PileTemplateDTO> pileTemplates = List.of();
        var templates = pileTemplateRepository.findByStationVersionIdOrderByPileIndex(newBsVersion.getId());
        pileTemplates = templates.stream()
                .map(t -> BatterySwapStationDetailDTO.PileTemplateDTO.builder()
                        .id(t.getId().toString())
                        .pileIndex(t.getPileIndex())
                        .slotsPerPile(t.getSlotsPerPile())
                        .slots(List.of())
                        .build())
                .toList();

        return BatterySwapStationDetailDTO.builder()
                .id(listDTO.getId())
                .providerId(listDTO.getProviderId())
                .stationCreatedAt(listDTO.getStationCreatedAt())
                .publishedVersionId(listDTO.getPublishedVersionId())
                .publishedVersionNo(listDTO.getPublishedVersionNo())
                .name(newStationVersion != null ? newStationVersion.getName() : listDTO.getName())
                .address(newStationVersion != null ? newStationVersion.getAddress() : listDTO.getAddress())
                .lat(newStationVersion != null && newStationVersion.getLocation() != null
                        ? newStationVersion.getLocation().getY() : listDTO.getLat())
                .lng(newStationVersion != null && newStationVersion.getLocation() != null
                        ? newStationVersion.getLocation().getX() : listDTO.getLng())
                .operatingHours(newBsVersion.getOperatingHours())
                .workflowStatus(newBsVersion.getWorkflowStatus().name())
                .publishedAt(listDTO.getPublishedAt())
                .createdBy(listDTO.getCreatedBy())
                .totalBatteries(newBsVersion.getTotalBatteries())
                .availableBatteries(listDTO.getAvailableBatteries())
                .avgChargePowerKw(newBsVersion.getAvgChargePowerKw())
                .parkingFee(newBsVersion.getParkingFee() != null ? newBsVersion.getParkingFee().toString() : listDTO.getParkingFee())
                .totalPiles(listDTO.getTotalPiles())
                .totalSlots(newBsVersion.getTotalSlotCount())
                .trustScore(listDTO.getTrustScore())
                .trustLevel(listDTO.getTrustLevel())
                .totalVersions(listDTO.getTotalVersions())
                .pendingCRs(listDTO.getPendingCRs())
                .pileTemplates(pileTemplates)
                .note(newBsVersion.getNote())
                .build();
    }

    private Point createPoint(double lng, double lat) {
        Coordinate coordinate = new Coordinate(lng, lat);
        return GEOMETRY_FACTORY.createPoint(coordinate);
    }

    private List<BatterySwapPileTemplateEntity> buildPileTemplates(
            List<UpdateBatterySwapStationDTO.PileTemplateDTO> templates,
            BatterySwapStationVersionEntity version) {
        return templates.stream()
                .sorted((a, b) -> Integer.compare(a.getPileIndex(), b.getPileIndex()))
                .map(t -> {
                    BatterySwapPileTemplateEntity pile = BatterySwapPileTemplateEntity.builder()
                            .id(UUID.randomUUID())
                            .pileIndex(t.getPileIndex())
                            .slotsPerPile(t.getSlotsPerPile())
                            .stationVersion(version)
                            .slotTemplates(new ArrayList<>())
                            .build();
                    if (t.getSlots() != null) {
                        for (UpdateBatterySwapStationDTO.SlotTemplateDTO slotDto : t.getSlots()) {
                            BatterySwapSlotTemplateEntity slot = BatterySwapSlotTemplateEntity.builder()
                                    .id(UUID.randomUUID())
                                    .slotIndex(slotDto.getSlotIndex())
                                    .batteryCapacityKwh(slotDto.getBatteryCapacityKwh())
                                    .pileTemplate(pile)
                                    .build();
                            pile.getSlotTemplates().add(slot);
                        }
                    }
                    return pile;
                })
                .collect(Collectors.toList());
    }

    private List<BatterySwapPileTemplateEntity> buildDefaultPileTemplates(
            int totalBatteries, BatterySwapStationVersionEntity version) {
        int slotsPerPile = 6;
        int numPiles = (int) Math.ceil((double) totalBatteries / slotsPerPile);
        List<BatterySwapPileTemplateEntity> piles = new ArrayList<>();
        for (int i = 0; i < numPiles; i++) {
            int slotsInThisPile = Math.min(slotsPerPile, totalBatteries - (i * slotsPerPile));
            BatterySwapPileTemplateEntity pile = BatterySwapPileTemplateEntity.builder()
                    .id(UUID.randomUUID())
                    .pileIndex(i + 1)
                    .slotsPerPile(slotsInThisPile)
                    .stationVersion(version)
                    .slotTemplates(new ArrayList<>())
                    .build();
            for (int j = 0; j < slotsInThisPile; j++) {
                BatterySwapSlotTemplateEntity slot = BatterySwapSlotTemplateEntity.builder()
                        .id(UUID.randomUUID())
                        .slotIndex(j)
                        .batteryCapacityKwh(new java.math.BigDecimal("60.0"))
                        .pileTemplate(pile)
                        .build();
                pile.getSlotTemplates().add(slot);
            }
            piles.add(pile);
        }
        return piles;
    }
}
