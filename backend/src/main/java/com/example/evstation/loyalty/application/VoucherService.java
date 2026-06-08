package com.example.evstation.loyalty.application;

import com.example.evstation.common.error.BusinessException;
import com.example.evstation.common.error.ErrorCode;
import com.example.evstation.loyalty.domain.*;
import com.example.evstation.loyalty.infrastructure.jpa.*;
import com.example.evstation.booking.infrastructure.jpa.BookingJpaRepository;
import com.example.evstation.booking.infrastructure.jpa.BookingEntity;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class VoucherService {

    private final VoucherDefinitionJpaRepository definitionRepository;
    private final VoucherRedemptionJpaRepository redemptionRepository;
    private final LoyaltyPointService loyaltyPointService;
    private final BookingJpaRepository bookingRepository;
    private final Clock clock;

    private static final String VOUCHER_CODE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    @Transactional(readOnly = true)
    public List<VoucherDefinitionEntity> getAvailableVouchers(UUID userId) {
        Instant now = Instant.now(clock);
        return definitionRepository.findAvailableActive(VoucherStatus.ACTIVE, now);
    }

    @Transactional
    public VoucherRedemptionEntity redeemVoucher(UUID userId, UUID definitionId) {
        VoucherDefinitionEntity def = definitionRepository.findById(definitionId)
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_DEFINITION_NOT_FOUND, "Voucher not found"));

        if (def.getStatus() != VoucherStatus.ACTIVE) {
            throw new BusinessException(ErrorCode.VOUCHER_NOT_ACTIVE, "Voucher is not active");
        }

        Instant now = Instant.now(clock);
        if (def.getStartDate() != null && now.isBefore(def.getStartDate())) {
            throw new BusinessException(ErrorCode.VOUCHER_NOT_ACTIVE, "Voucher is not yet available");
        }
        if (def.getEndDate() != null && now.isAfter(def.getEndDate())) {
            throw new BusinessException(ErrorCode.VOUCHER_NOT_ACTIVE, "Voucher has ended");
        }

        // Deduct points
        String desc = "Redeemed voucher: " + def.getName();
        loyaltyPointService.redeemPoints(userId, def.getPointCost(), null, desc);

        // Create redemption
        String voucherCode = generateUniqueCode();
        Instant expiresAt = now.plusSeconds(def.getValidityDays() * 86400L);

        VoucherRedemptionEntity redemption = VoucherRedemptionEntity.builder()
                .userId(userId)
                .voucherDefinitionId(definitionId)
                .voucherCode(voucherCode)
                .status(RedemptionStatus.REDEEMED)
                .pointsSpent(def.getPointCost())
                .redeemedAt(now)
                .expiresAt(expiresAt)
                .build();

        redemption = redemptionRepository.save(redemption);
        log.info("User {} redeemed voucher {}, code={}", userId, def.getCode(), voucherCode);
        return redemption;
    }

    @Transactional(readOnly = true)
    public Page<VoucherRedemptionEntity> getMyRedemptions(UUID userId, RedemptionStatus status, Pageable pageable) {
        if (status != null) {
            return redemptionRepository.findByUserIdAndStatusOrderByRedeemedAtDesc(userId, status, pageable);
        }
        return redemptionRepository.findByUserIdOrderByRedeemedAtDesc(userId, pageable);
    }

    @Transactional(readOnly = true)
    public VoucherRedemptionEntity getRedemptionDetail(UUID redemptionId, UUID userId) {
        VoucherRedemptionEntity redemption = redemptionRepository.findById(redemptionId)
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_REDEMPTION_NOT_FOUND, "Redemption not found"));
        if (!redemption.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "Access denied");
        }
        return redemption;
    }

    @Transactional
    public VoucherRedemptionEntity applyVoucherToBooking(UUID redemptionId, UUID bookingId, UUID userId) {
        VoucherRedemptionEntity redemption = redemptionRepository.findById(redemptionId)
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_REDEMPTION_NOT_FOUND, "Redemption not found"));

        if (!redemption.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "Access denied");
        }
        if (redemption.getStatus() == RedemptionStatus.USED) {
            throw new BusinessException(ErrorCode.VOUCHER_ALREADY_USED, "Voucher already used");
        }
        if (redemption.getStatus() == RedemptionStatus.EXPIRED) {
            throw new BusinessException(ErrorCode.VOUCHER_EXPIRED, "Voucher has expired");
        }

        Instant now = Instant.now(clock);
        if (now.isAfter(redemption.getExpiresAt())) {
            redemption.setStatus(RedemptionStatus.EXPIRED);
            redemptionRepository.save(redemption);
            throw new BusinessException(ErrorCode.VOUCHER_EXPIRED, "Voucher has expired");
        }

        // Validate booking belongs to user
        BookingEntity booking = bookingRepository.findByIdAndUserId(bookingId, userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.BOOKING_NOT_FOUND, "Booking not found"));

        VoucherDefinitionEntity def = definitionRepository.findById(redemption.getVoucherDefinitionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_DEFINITION_NOT_FOUND));
        if (def.getVoucherType() == VoucherType.FREE_SERVICE) {
            if (!"CHARGING".equals(def.getServiceType())) {
                throw new BusinessException(ErrorCode.VOUCHER_SERVICE_TYPE_MISMATCH, "Voucher is not for charging");
            }
        }

        // Calculate discount based on booking amount from priceSnapshot
        Map<String, Object> priceSnapshot = booking.getPriceSnapshot();
        int bookingAmount = 0;
        if (priceSnapshot != null && priceSnapshot.containsKey("amount")) {
            Object amountObj = priceSnapshot.get("amount");
            if (amountObj instanceof Number) {
                bookingAmount = ((Number) amountObj).intValue();
            }
        }

        int discountAmount;
        if (def.getVoucherType() == VoucherType.PERCENT_DISCOUNT) {
            int percent = def.getDiscountPercent() != null ? def.getDiscountPercent() : 0;
            discountAmount = (bookingAmount * percent) / 100;
            Integer maxValue = def.getMaxValueVnd();
            if (maxValue != null && discountAmount > maxValue) {
                discountAmount = maxValue;
            }
        } else {
            // FREE_SERVICE: full free
            discountAmount = bookingAmount;
        }

        Map<String, Object> metadata = new HashMap<>();
        metadata.put("bookingId", bookingId.toString());
        metadata.put("appliedAt", now.toString());
        metadata.put("discountAmount", discountAmount);
        metadata.put("bookingAmount", bookingAmount);
        metadata.put("voucherCode", redemption.getVoucherCode());
        metadata.put("voucherName", def.getName());

        redemption.setStatus(RedemptionStatus.USED);
        redemption.setUsedAt(now);
        redemption.setBookingId(bookingId);
        redemption.setServiceType("CHARGING");
        redemption.setMetadata(metadata);

        redemption = redemptionRepository.save(redemption);

        // Link voucher to booking so payment can read the discount
        booking.setVoucherRedemptionId(redemptionId);
        bookingRepository.save(booking);

        return redemption;
    }

    @Transactional
    public VoucherRedemptionEntity applyVoucherToSwap(UUID redemptionId, UUID reservationId, UUID userId) {
        VoucherRedemptionEntity redemption = redemptionRepository.findById(redemptionId)
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_REDEMPTION_NOT_FOUND, "Redemption not found"));

        if (!redemption.getUserId().equals(userId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "Access denied");
        }
        if (redemption.getStatus() == RedemptionStatus.USED) {
            throw new BusinessException(ErrorCode.VOUCHER_ALREADY_USED, "Voucher already used");
        }
        if (redemption.getStatus() == RedemptionStatus.EXPIRED) {
            throw new BusinessException(ErrorCode.VOUCHER_EXPIRED, "Voucher has expired");
        }

        Instant now = Instant.now(clock);
        if (now.isAfter(redemption.getExpiresAt())) {
            redemption.setStatus(RedemptionStatus.EXPIRED);
            redemptionRepository.save(redemption);
            throw new BusinessException(ErrorCode.VOUCHER_EXPIRED, "Voucher has expired");
        }

        VoucherDefinitionEntity def = definitionRepository.findById(redemption.getVoucherDefinitionId())
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_DEFINITION_NOT_FOUND));
        if (def.getVoucherType() == VoucherType.FREE_SERVICE) {
            if (!"BATTERY_SWAP".equals(def.getServiceType())) {
                throw new BusinessException(ErrorCode.VOUCHER_SERVICE_TYPE_MISMATCH, "Voucher is not for battery swap");
            }
        }

        Map<String, Object> metadata = new HashMap<>();
        metadata.put("reservationId", reservationId.toString());
        metadata.put("appliedAt", now.toString());

        redemption.setStatus(RedemptionStatus.USED);
        redemption.setUsedAt(now);
        redemption.setBookingId(reservationId);
        redemption.setServiceType("BATTERY_SWAP");
        redemption.setMetadata(metadata);

        return redemptionRepository.save(redemption);
    }

    @Transactional
    public int expireRedemptions() {
        Instant now = Instant.now(clock);
        int count = redemptionRepository.expireRedemptions(RedemptionStatus.REDEEMED, RedemptionStatus.EXPIRED, now);
        log.info("Expired {} voucher redemptions", count);
        return count;
    }

    @Transactional(readOnly = true)
    public long getRedemptionCount(UUID definitionId) {
        return redemptionRepository.countTotalRedemptions(definitionId);
    }

    // CRUD for admin
    @Transactional(readOnly = true)
    public List<VoucherDefinitionEntity> getAllDefinitions() {
        return definitionRepository.findAll();
    }

    @Transactional(readOnly = true)
    public VoucherDefinitionEntity getDefinitionById(UUID id) {
        return definitionRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_DEFINITION_NOT_FOUND));
    }

    @Transactional
    public VoucherDefinitionEntity createDefinition(VoucherDefinitionEntity def) {
        def.setId(UUID.randomUUID());
        def.setStatus(VoucherStatus.ACTIVE);
        def.setCreatedAt(Instant.now(clock));
        def.setUpdatedAt(Instant.now(clock));
        return definitionRepository.save(def);
    }

    @Transactional
    public VoucherDefinitionEntity updateDefinition(UUID id, VoucherDefinitionEntity updates) {
        VoucherDefinitionEntity existing = definitionRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_DEFINITION_NOT_FOUND));
        existing.setName(updates.getName());
        existing.setDescription(updates.getDescription());
        existing.setVoucherType(updates.getVoucherType());
        existing.setPointCost(updates.getPointCost());
        existing.setDiscountPercent(updates.getDiscountPercent());
        existing.setMaxValueVnd(updates.getMaxValueVnd());
        existing.setServiceType(updates.getServiceType());
        existing.setStartDate(updates.getStartDate());
        existing.setEndDate(updates.getEndDate());
        existing.setValidityDays(updates.getValidityDays());
        existing.setUpdatedAt(Instant.now(clock));
        return definitionRepository.save(existing);
    }

    @Transactional
    public VoucherDefinitionEntity updateDefinitionStatus(UUID id, VoucherStatus status) {
        VoucherDefinitionEntity def = definitionRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.VOUCHER_DEFINITION_NOT_FOUND));
        def.setStatus(status);
        def.setUpdatedAt(Instant.now(clock));
        return definitionRepository.save(def);
    }

    @Transactional(readOnly = true)
    public Page<VoucherRedemptionEntity> getAllRedemptions(RedemptionStatus status, Pageable pageable) {
        if (status != null) {
            return redemptionRepository.findByStatusOrderByRedeemedAtDesc(status, pageable);
        }
        return redemptionRepository.findAll(pageable);
    }

    @Transactional(readOnly = true)
    public int getDiscountAmountForRedemption(UUID redemptionId) {
        return redemptionRepository.findById(redemptionId)
                .map(r -> {
                    Map<String, Object> meta = r.getMetadata();
                    if (meta != null && meta.containsKey("discountAmount")) {
                        Object da = meta.get("discountAmount");
                        if (da instanceof Number) {
                            return ((Number) da).intValue();
                        }
                    }
                    return 0;
                })
                .orElse(0);
    }

    private String generateUniqueCode() {
        String code;
        int attempts = 0;
        do {
            code = "VG-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
            attempts++;
        } while (redemptionRepository.existsByVoucherCode(code) && attempts < 10);
        return code;
    }
}
