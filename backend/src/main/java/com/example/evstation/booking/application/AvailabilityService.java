package com.example.evstation.booking.application;

import com.example.evstation.api.ev_user_mobile.dto.AvailabilityResponseDTO;
import com.example.evstation.api.ev_user_mobile.dto.AvailabilitySlotDTO;
import com.example.evstation.api.ev_user_mobile.dto.ChargerUnitAvailabilityDTO;
import com.example.evstation.api.ev_user_mobile.dto.ChargerUnitDTO;
import com.example.evstation.booking.domain.BookingStatus;
import com.example.evstation.booking.domain.ChargerUnitStatus;
import com.example.evstation.booking.infrastructure.jpa.BookingEntity;
import com.example.evstation.booking.infrastructure.jpa.BookingJpaRepository;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitEntity;
import com.example.evstation.booking.infrastructure.jpa.ChargerUnitJpaRepository;
import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.station.domain.PowerType;
import com.example.evstation.station.domain.WorkflowStatus;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AvailabilityService {
    
    private final ChargerUnitJpaRepository chargerUnitRepository;
    private final BookingJpaRepository bookingRepository;
    private final StationVersionJpaRepository stationVersionRepository;
    
    /**
     * Get availability for a station on a specific date
     */
    @Transactional(readOnly = true)
    public AvailabilityResponseDTO getAvailability(
            UUID stationId,
            LocalDate date,
            String timezone,
            Integer slotMinutes,
            PowerType powerType,
            java.math.BigDecimal minPowerKw) {
        
        log.debug("Getting availability: stationId={}, date={}, timezone={}, slotMinutes={}", 
                stationId, date, timezone, slotMinutes);
        
        // Validate station has published version
        boolean stationPublished = stationVersionRepository
                .findByStationIdAndWorkflowStatus(stationId, WorkflowStatus.PUBLISHED)
                .isPresent();
        
        if (!stationPublished) {
            throw new BusinessException(ErrorCode.NOT_FOUND, 
                    "Station not found or does not have a published version");
        }
        
        // Parse timezone (default to Asia/Bangkok)
        ZoneId zoneId = timezone != null ? ZoneId.of(timezone) : ZoneId.of("Asia/Bangkok");
        int slotDuration = slotMinutes != null ? slotMinutes : 30;
        
        // Build day range (start of day to end of day in timezone)
        ZonedDateTime dayStartZoned = date.atStartOfDay(zoneId);
        ZonedDateTime dayEndZoned = date.plusDays(1).atStartOfDay(zoneId);
        Instant dayStart = dayStartZoned.toInstant();
        Instant dayEnd = dayEndZoned.toInstant();
        
        // Get charger units (filter by power type and min power if provided)
        List<ChargerUnitEntity> chargerUnits;
        if (powerType != null) {
            chargerUnits = chargerUnitRepository.findByStationIdAndPowerType(
                    stationId, ChargerUnitStatus.ACTIVE, powerType, minPowerKw);
        } else {
            chargerUnits = chargerUnitRepository.findByStationIdAndStatusOrderByLabel(
                    stationId, ChargerUnitStatus.ACTIVE);
            if (minPowerKw != null) {
                chargerUnits = chargerUnits.stream()
                        .filter(cu -> cu.getPowerKw() == null || cu.getPowerKw().compareTo(minPowerKw) >= 0)
                        .collect(Collectors.toList());
            }
        }
        
        if (chargerUnits.isEmpty()) {
            return AvailabilityResponseDTO.builder()
                    .stationId(stationId)
                    .date(date.toString())
                    .slotTimes(List.of())
                    .availability(List.of())
                    .build();
        }
        
        List<UUID> chargerUnitIds = chargerUnits.stream()
                .map(ChargerUnitEntity::getId)
                .collect(Collectors.toList());
        
        // Get bookings for these charger units in the day range
        List<BookingEntity> bookings = bookingRepository.findBookingsForAvailability(
                chargerUnitIds, dayStart, dayEnd);
        
        // Build slot times
        List<Instant> slotTimes = new ArrayList<>();
        ZonedDateTime current = dayStartZoned;
        while (current.isBefore(dayEndZoned)) {
            slotTimes.add(current.toInstant());
            current = current.plusMinutes(slotDuration);
        }
        
        // Build availability matrix
        Instant now = Instant.now();
        Map<UUID, List<BookingEntity>> bookingsByUnit = bookings.stream()
                .collect(Collectors.groupingBy(BookingEntity::getChargerUnitId));
        
        List<ChargerUnitAvailabilityDTO> availability = chargerUnits.stream()
                .map(unit -> {
                    ChargerUnitDTO unitDTO = ChargerUnitDTO.builder()
                            .id(unit.getId())
                            .stationId(unit.getStationId())
                            .label(unit.getLabel())
                            .powerType(unit.getPowerType().name())
                            .powerKw(unit.getPowerKw())
                            .pricePerSlot(unit.getPricePerSlot())
                            .status(unit.getStatus().name())
                            .build();
                    
                    List<BookingEntity> unitBookings = bookingsByUnit.getOrDefault(unit.getId(), List.of());
                    List<AvailabilitySlotDTO> slots = buildSlots(slotTimes, slotDuration, unitBookings, now, zoneId);
                    
                    return ChargerUnitAvailabilityDTO.builder()
                            .chargerUnit(unitDTO)
                            .slots(slots)
                            .build();
                })
                .collect(Collectors.toList());
        
        return AvailabilityResponseDTO.builder()
                .stationId(stationId)
                .date(date.toString())
                .slotTimes(slotTimes)
                .availability(availability)
                .build();
    }
    
    private List<AvailabilitySlotDTO> buildSlots(
            List<Instant> slotTimes,
            int slotDurationMinutes,
            List<BookingEntity> bookings,
            Instant now,
            ZoneId zoneId) {
        
        List<AvailabilitySlotDTO> slots = new ArrayList<>();
        
        for (int i = 0; i < slotTimes.size(); i++) {
            Instant slotStart = slotTimes.get(i);
            Instant slotEnd = i < slotTimes.size() - 1 
                    ? slotTimes.get(i + 1)
                    : slotStart.plus(slotDurationMinutes, ChronoUnit.MINUTES);
            
            String status = determineSlotStatus(slotStart, slotEnd, bookings, now);
            
            slots.add(AvailabilitySlotDTO.builder()
                    .startTime(slotStart)
                    .endTime(slotEnd)
                    .status(status)
                    .build());
        }
        
        return slots;
    }
    
    private String determineSlotStatus(
            Instant slotStart,
            Instant slotEnd,
            List<BookingEntity> bookings,
            Instant now) {
        
        for (BookingEntity booking : bookings) {
            // Check if slot overlaps with booking
            if (slotStart.isBefore(booking.getEndTime()) && slotEnd.isAfter(booking.getStartTime())) {
                if (booking.getStatus() == BookingStatus.CONFIRMED) {
                    return "BOOKED";
                } else if (booking.getStatus() == BookingStatus.HOLD && 
                          booking.getHoldExpiresAt().isAfter(now)) {
                    return "HELD";
                }
                // EXPIRED or CANCELLED bookings don't block
            }
        }
        
        return "AVAILABLE";
    }
}

