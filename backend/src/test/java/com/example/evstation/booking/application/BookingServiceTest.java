package com.example.evstation.booking.application;

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
import com.example.evstation.station.infrastructure.jpa.AuditLogEntity;
import com.example.evstation.station.infrastructure.jpa.AuditLogJpaRepository;
import com.example.evstation.station.infrastructure.jpa.StationVersionEntity;
import com.example.evstation.station.infrastructure.jpa.StationVersionJpaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("local")
@Transactional
@DisplayName("BookingService Tests")
class BookingServiceTest {

    private static final GeometryFactory GEOMETRY_FACTORY = new GeometryFactory(new PrecisionModel(), 4326);

    @Autowired
    private BookingService bookingService;

    @Autowired
    private BookingJpaRepository bookingRepository;

    @Autowired
    private ChargerUnitJpaRepository chargerUnitRepository;

    @Autowired
    private StationVersionJpaRepository stationVersionRepository;

    @Autowired
    private AuditLogJpaRepository auditLogRepository;

    @Autowired
    private Clock clock;

    private UUID userId;
    private UUID stationId;
    private UUID stationVersionId;
    private UUID chargerUnitId;
    private Instant now;
    private Instant futureStart;
    private Instant futureEnd;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        stationId = UUID.randomUUID();
        stationVersionId = UUID.randomUUID();
        chargerUnitId = UUID.randomUUID();
        now = clock.instant();
        futureStart = now.plus(Duration.ofHours(1));
        futureEnd = futureStart.plus(Duration.ofHours(2));

        // Create station version with PUBLISHED status
        StationVersionEntity stationVersion = StationVersionEntity.builder()
                .id(stationVersionId)
                .stationId(stationId)
                .versionNo(1)
                .workflowStatus(WorkflowStatus.PUBLISHED)
                .name("Test Station")
                .address("Test Address")
                .location(GEOMETRY_FACTORY.createPoint(new Coordinate(105.8, 21.0)))
                .createdBy(UUID.randomUUID())
                .createdAt(now)
                .publishedAt(now)
                .build();
        stationVersionRepository.save(stationVersion);

        // Create charger unit
        ChargerUnitEntity chargerUnit = ChargerUnitEntity.builder()
                .id(chargerUnitId)
                .stationId(stationId)
                .stationVersionId(stationVersionId)
                .label("Unit 1")
                .powerType(PowerType.DC)
                .powerKw(BigDecimal.valueOf(50.0))
                .pricePerHour(50000)
                .status(ChargerUnitStatus.ACTIVE)
                .createdAt(now)
                .build();
        chargerUnitRepository.save(chargerUnit);
    }

    @Test
    @DisplayName("Should create booking successfully")
    void shouldCreateBookingSuccessfully() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);

        // When
        BookingResponseDTO response = bookingService.createBooking(request, userId);

        // Then
        assertThat(response).isNotNull();
        assertThat(response.getId()).isNotNull();
        assertThat(response.getUserId()).isEqualTo(userId);
        assertThat(response.getStationId()).isEqualTo(stationId);
        assertThat(response.getChargerUnitId()).isEqualTo(chargerUnitId);
        assertThat(response.getStartTime()).isEqualTo(futureStart);
        assertThat(response.getEndTime()).isEqualTo(futureEnd);
        assertThat(response.getStatus()).isEqualTo("HOLD");
        assertThat(response.getHoldExpiresAt()).isAfter(now);
        assertThat(response.getHoldExpiresAt()).isBeforeOrEqualTo(now.plus(Duration.ofMinutes(10).plusSeconds(1)));
        assertThat(response.getPriceSnapshot()).isNotNull();
        assertThat(response.getPriceSnapshot().get("unitLabel")).isEqualTo("Unit 1");
        assertThat(response.getPriceSnapshot().get("powerType")).isEqualTo("DC");
        assertThat(response.getPriceSnapshot().get("durationMinutes")).isEqualTo(120);

        // Verify booking saved in database
        Optional<BookingEntity> saved = bookingRepository.findById(response.getId());
        assertThat(saved).isPresent();
        assertThat(saved.get().getStatus()).isEqualTo(BookingStatus.HOLD);

        // Verify audit log created
        List<AuditLogEntity> auditLogs = auditLogRepository.findByEntityTypeAndEntityIdOrderByCreatedAtDesc(
                "BOOKING", response.getId());
        assertThat(auditLogs).hasSize(1);
        assertThat(auditLogs.get(0).getAction()).isEqualTo("BOOKING_HOLD_CREATED");
    }

    @Test
    @DisplayName("Should throw exception when station not found")
    void shouldThrowExceptionWhenStationNotFound() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(UUID.randomUUID());
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    @Test
    @DisplayName("Should throw exception when station not published")
    void shouldThrowExceptionWhenStationNotPublished() {
        // Given - create station version with DRAFT status
        UUID draftStationId = UUID.randomUUID();
        StationVersionEntity draftVersion = StationVersionEntity.builder()
                .id(UUID.randomUUID())
                .stationId(draftStationId)
                .versionNo(1)
                .workflowStatus(WorkflowStatus.DRAFT)
                .name("Draft Station")
                .address("Draft Address")
                .location(GEOMETRY_FACTORY.createPoint(new Coordinate(105.8, 21.0)))
                .createdBy(UUID.randomUUID())
                .createdAt(now)
                .build();
        stationVersionRepository.save(draftVersion);

        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(draftStationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    @Test
    @DisplayName("Should throw exception when charger unit not found")
    void shouldThrowExceptionWhenChargerUnitNotFound() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(UUID.randomUUID());
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.CHARGER_UNIT_NOT_FOUND);
    }

    @Test
    @DisplayName("Should throw exception when charger unit belongs to different station")
    void shouldThrowExceptionWhenChargerUnitBelongsToDifferentStation() {
        // Given - create another station and charger unit
        UUID otherStationId = UUID.randomUUID();
        UUID otherStationVersionId = UUID.randomUUID();
        StationVersionEntity otherStationVersion = StationVersionEntity.builder()
                .id(otherStationVersionId)
                .stationId(otherStationId)
                .versionNo(1)
                .workflowStatus(WorkflowStatus.PUBLISHED)
                .name("Other Station")
                .address("Other Address")
                .location(GEOMETRY_FACTORY.createPoint(new Coordinate(105.9, 21.1)))
                .createdBy(UUID.randomUUID())
                .createdAt(now)
                .publishedAt(now)
                .build();
        stationVersionRepository.save(otherStationVersion);

        UUID otherChargerUnitId = UUID.randomUUID();
        ChargerUnitEntity otherUnit = ChargerUnitEntity.builder()
                .id(otherChargerUnitId)
                .stationId(otherStationId)
                .stationVersionId(otherStationVersionId)
                .label("Other Unit")
                .powerType(PowerType.AC)
                .pricePerHour(30000)
                .status(ChargerUnitStatus.ACTIVE)
                .createdAt(now)
                .build();
        chargerUnitRepository.save(otherUnit);

        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId); // Try to book with stationId but other charger unit
        request.setChargerUnitId(otherChargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.CHARGER_UNIT_NOT_FOUND);
    }

    @Test
    @DisplayName("Should throw exception when charger unit is inactive")
    void shouldThrowExceptionWhenChargerUnitIsInactive() {
        // Given - update charger unit to INACTIVE
        ChargerUnitEntity inactiveUnit = chargerUnitRepository.findById(chargerUnitId).orElseThrow();
        inactiveUnit.setStatus(ChargerUnitStatus.INACTIVE);
        chargerUnitRepository.save(inactiveUnit);

        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.CHARGER_UNIT_INACTIVE);
    }

    @Test
    @DisplayName("Should throw exception when charger unit is in maintenance")
    void shouldThrowExceptionWhenChargerUnitIsInMaintenance() {
        // Given - update charger unit to MAINTENANCE
        ChargerUnitEntity maintenanceUnit = chargerUnitRepository.findById(chargerUnitId).orElseThrow();
        maintenanceUnit.setStatus(ChargerUnitStatus.MAINTENANCE);
        chargerUnitRepository.save(maintenanceUnit);

        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.CHARGER_UNIT_INACTIVE);
    }

    @Test
    @DisplayName("Should throw exception when startTime is in the past")
    void shouldThrowExceptionWhenStartTimeIsInThePast() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(now.minus(Duration.ofHours(1)));
        request.setEndTime(futureEnd);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_TIME_RANGE);
    }

    @Test
    @DisplayName("Should throw exception when endTime is before startTime")
    void shouldThrowExceptionWhenEndTimeIsBeforeStartTime() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureStart.minus(Duration.ofHours(1)));

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_TIME_RANGE);
    }

    @Test
    @DisplayName("Should throw exception when endTime equals startTime")
    void shouldThrowExceptionWhenEndTimeEqualsStartTime() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureStart);

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_TIME_RANGE);
    }

    @Test
    @DisplayName("Should throw exception when duration is too short")
    void shouldThrowExceptionWhenDurationIsTooShort() {
        // Given - duration less than 15 minutes
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureStart.plus(Duration.ofMinutes(10)));

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_TIME_RANGE);
    }

    @Test
    @DisplayName("Should allow minimum duration of 15 minutes")
    void shouldAllowMinimumDurationOf15Minutes() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureStart.plus(Duration.ofMinutes(15)));

        // When
        BookingResponseDTO response = bookingService.createBooking(request, userId);

        // Then
        assertThat(response).isNotNull();
        assertThat(response.getStatus()).isEqualTo("HOLD");
    }

    @Test
    @DisplayName("Should throw exception when duration is too long")
    void shouldThrowExceptionWhenDurationIsTooLong() {
        // Given - duration more than 4 hours
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureStart.plus(Duration.ofHours(5)));

        // When/Then
        assertThatThrownBy(() -> bookingService.createBooking(request, userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_TIME_RANGE);
    }

    @Test
    @DisplayName("Should allow maximum duration of 4 hours")
    void shouldAllowMaximumDurationOf4Hours() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureStart.plus(Duration.ofHours(4)));

        // When
        BookingResponseDTO response = bookingService.createBooking(request, userId);

        // Then
        assertThat(response).isNotNull();
        assertThat(response.getStatus()).isEqualTo("HOLD");
    }

    @Test
    @DisplayName("Should calculate price snapshot correctly")
    void shouldCalculatePriceSnapshotCorrectly() {
        // Given - 2 hours booking
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureStart.plus(Duration.ofHours(2)));

        // When
        BookingResponseDTO response = bookingService.createBooking(request, userId);

        // Then
        assertThat(response.getPriceSnapshot()).isNotNull();
        assertThat(response.getPriceSnapshot().get("unitLabel")).isEqualTo("Unit 1");
        assertThat(response.getPriceSnapshot().get("powerType")).isEqualTo("DC");
        assertThat(response.getPriceSnapshot().get("powerKw")).isEqualTo(50.0);
        assertThat(response.getPriceSnapshot().get("pricePerHour")).isEqualTo(50000);
        assertThat(response.getPriceSnapshot().get("durationMinutes")).isEqualTo(120);
        // amount = 50000 * 2 = 100000
        assertThat(response.getPriceSnapshot().get("amount")).isEqualTo(100000);
    }

    @Test
    @DisplayName("Should get my bookings with pagination")
    void shouldGetMyBookingsWithPagination() {
        // Given - create multiple bookings
        CreateBookingDTO request1 = new CreateBookingDTO();
        request1.setStationId(stationId);
        request1.setChargerUnitId(chargerUnitId);
        request1.setStartTime(futureStart);
        request1.setEndTime(futureEnd);
        bookingService.createBooking(request1, userId);

        CreateBookingDTO request2 = new CreateBookingDTO();
        request2.setStationId(stationId);
        request2.setChargerUnitId(chargerUnitId);
        request2.setStartTime(futureStart.plus(Duration.ofDays(1)));
        request2.setEndTime(futureEnd.plus(Duration.ofDays(1)));
        bookingService.createBooking(request2, userId);

        // When
        Page<BookingResponseDTO> page = bookingService.getMyBookings(userId, PageRequest.of(0, 10));

        // Then
        assertThat(page.getContent()).hasSize(2);
        assertThat(page.getTotalElements()).isEqualTo(2);
        // Should be ordered by createdAt DESC
        assertThat(page.getContent().get(0).getCreatedAt())
                .isAfterOrEqualTo(page.getContent().get(1).getCreatedAt());
    }

    @Test
    @DisplayName("Should get booking by ID")
    void shouldGetBookingById() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);

        // When
        Optional<BookingResponseDTO> found = bookingService.getBooking(created.getId(), userId);

        // Then
        assertThat(found).isPresent();
        assertThat(found.get().getId()).isEqualTo(created.getId());
        assertThat(found.get().getUserId()).isEqualTo(userId);
    }

    @Test
    @DisplayName("Should return empty when booking not found")
    void shouldReturnEmptyWhenBookingNotFound() {
        // When
        Optional<BookingResponseDTO> found = bookingService.getBooking(UUID.randomUUID(), userId);

        // Then
        assertThat(found).isEmpty();
    }

    @Test
    @DisplayName("Should return empty when booking belongs to different user")
    void shouldReturnEmptyWhenBookingBelongsToDifferentUser() {
        // Given
        UUID otherUserId = UUID.randomUUID();
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, otherUserId);

        // When
        Optional<BookingResponseDTO> found = bookingService.getBooking(created.getId(), userId);

        // Then
        assertThat(found).isEmpty();
    }

    @Test
    @DisplayName("Should cancel booking with HOLD status")
    void shouldCancelBookingWithHoldStatus() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);

        // When
        BookingResponseDTO cancelled = bookingService.cancelBooking(created.getId(), userId);

        // Then
        assertThat(cancelled.getStatus()).isEqualTo("CANCELLED");
        Optional<BookingEntity> saved = bookingRepository.findById(created.getId());
        assertThat(saved).isPresent();
        assertThat(saved.get().getStatus()).isEqualTo(BookingStatus.CANCELLED);

        // Verify audit log
        List<AuditLogEntity> auditLogs = auditLogRepository.findByEntityTypeAndEntityIdOrderByCreatedAtDesc(
                "BOOKING", created.getId());
        assertThat(auditLogs).hasSize(2); // HOLD_CREATED and CANCELLED
        assertThat(auditLogs.get(0).getAction()).isEqualTo("BOOKING_CANCELLED");
    }

    @Test
    @DisplayName("Should cancel booking with CONFIRMED status")
    void shouldCancelBookingWithConfirmedStatus() {
        // Given - create booking and manually set to CONFIRMED (simulating payment)
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);

        BookingEntity booking = bookingRepository.findById(created.getId()).orElseThrow();
        booking.setStatus(BookingStatus.CONFIRMED);
        bookingRepository.save(booking);

        // When
        BookingResponseDTO cancelled = bookingService.cancelBooking(created.getId(), userId);

        // Then
        assertThat(cancelled.getStatus()).isEqualTo("CANCELLED");
    }

    @Test
    @DisplayName("Should throw exception when cancelling booking with CANCELLED status")
    void shouldThrowExceptionWhenCancellingBookingWithCancelledStatus() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);
        bookingService.cancelBooking(created.getId(), userId);

        // When/Then
        assertThatThrownBy(() -> bookingService.cancelBooking(created.getId(), userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_STATE);
    }

    @Test
    @DisplayName("Should throw exception when cancelling booking with EXPIRED status")
    void shouldThrowExceptionWhenCancellingBookingWithExpiredStatus() {
        // Given
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);

        BookingEntity booking = bookingRepository.findById(created.getId()).orElseThrow();
        booking.setStatus(BookingStatus.EXPIRED);
        bookingRepository.save(booking);

        // When/Then
        assertThatThrownBy(() -> bookingService.cancelBooking(created.getId(), userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.INVALID_STATE);
    }

    @Test
    @DisplayName("Should throw exception when booking not found for cancellation")
    void shouldThrowExceptionWhenBookingNotFoundForCancellation() {
        // When/Then
        assertThatThrownBy(() -> bookingService.cancelBooking(UUID.randomUUID(), userId))
                .isInstanceOf(BusinessException.class)
                .extracting("errorCode")
                .isEqualTo(ErrorCode.NOT_FOUND);
    }

    @Test
    @DisplayName("Should expire HOLD bookings")
    void shouldExpireHoldBookings() {
        // Given - create booking with expired hold
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);

        // Manually set hold_expires_at to past
        BookingEntity booking = bookingRepository.findById(created.getId()).orElseThrow();
        booking.setHoldExpiresAt(now.minus(Duration.ofMinutes(1)));
        bookingRepository.save(booking);

        // When
        int expiredCount = bookingService.expireHoldBookings();

        // Then
        assertThat(expiredCount).isEqualTo(1);
        Optional<BookingEntity> expired = bookingRepository.findById(created.getId());
        assertThat(expired).isPresent();
        assertThat(expired.get().getStatus()).isEqualTo(BookingStatus.EXPIRED);

        // Verify audit log
        List<AuditLogEntity> auditLogs = auditLogRepository.findByEntityTypeAndEntityIdOrderByCreatedAtDesc(
                "BOOKING", created.getId());
        assertThat(auditLogs).hasSize(2); // HOLD_CREATED and EXPIRED
        assertThat(auditLogs.get(0).getAction()).isEqualTo("BOOKING_EXPIRED");
    }

    @Test
    @DisplayName("Should not expire bookings that are not HOLD")
    void shouldNotExpireBookingsThatAreNotHold() {
        // Given - create booking and set to CONFIRMED
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);

        BookingEntity booking = bookingRepository.findById(created.getId()).orElseThrow();
        booking.setStatus(BookingStatus.CONFIRMED);
        booking.setHoldExpiresAt(now.minus(Duration.ofMinutes(1)));
        bookingRepository.save(booking);

        // When
        int expiredCount = bookingService.expireHoldBookings();

        // Then
        assertThat(expiredCount).isEqualTo(0);
        Optional<BookingEntity> saved = bookingRepository.findById(created.getId());
        assertThat(saved).isPresent();
        assertThat(saved.get().getStatus()).isEqualTo(BookingStatus.CONFIRMED);
    }

    @Test
    @DisplayName("Should not expire HOLD bookings that haven't expired yet")
    void shouldNotExpireHoldBookingsThatHaventExpiredYet() {
        // Given - create booking with future hold_expires_at
        CreateBookingDTO request = new CreateBookingDTO();
        request.setStationId(stationId);
        request.setChargerUnitId(chargerUnitId);
        request.setStartTime(futureStart);
        request.setEndTime(futureEnd);
        BookingResponseDTO created = bookingService.createBooking(request, userId);

        // When
        int expiredCount = bookingService.expireHoldBookings();

        // Then
        assertThat(expiredCount).isEqualTo(0);
        Optional<BookingEntity> saved = bookingRepository.findById(created.getId());
        assertThat(saved).isPresent();
        assertThat(saved.get().getStatus()).isEqualTo(BookingStatus.HOLD);
    }

    @Test
    @DisplayName("Should expire multiple HOLD bookings")
    void shouldExpireMultipleHoldBookings() {
        // Given - create multiple bookings with expired holds
        UUID userId2 = UUID.randomUUID();
        CreateBookingDTO request1 = new CreateBookingDTO();
        request1.setStationId(stationId);
        request1.setChargerUnitId(chargerUnitId);
        request1.setStartTime(futureStart);
        request1.setEndTime(futureEnd);
        BookingResponseDTO created1 = bookingService.createBooking(request1, userId);

        CreateBookingDTO request2 = new CreateBookingDTO();
        request2.setStationId(stationId);
        request2.setChargerUnitId(chargerUnitId);
        request2.setStartTime(futureStart.plus(Duration.ofDays(1)));
        request2.setEndTime(futureEnd.plus(Duration.ofDays(1)));
        BookingResponseDTO created2 = bookingService.createBooking(request2, userId2);

        // Set both to expired
        BookingEntity booking1 = bookingRepository.findById(created1.getId()).orElseThrow();
        booking1.setHoldExpiresAt(now.minus(Duration.ofMinutes(1)));
        bookingRepository.save(booking1);

        BookingEntity booking2 = bookingRepository.findById(created2.getId()).orElseThrow();
        booking2.setHoldExpiresAt(now.minus(Duration.ofMinutes(1)));
        bookingRepository.save(booking2);

        // When
        int expiredCount = bookingService.expireHoldBookings();

        // Then
        assertThat(expiredCount).isEqualTo(2);
        assertThat(bookingRepository.findById(created1.getId()).orElseThrow().getStatus())
                .isEqualTo(BookingStatus.EXPIRED);
        assertThat(bookingRepository.findById(created2.getId()).orElseThrow().getStatus())
                .isEqualTo(BookingStatus.EXPIRED);
    }
}

