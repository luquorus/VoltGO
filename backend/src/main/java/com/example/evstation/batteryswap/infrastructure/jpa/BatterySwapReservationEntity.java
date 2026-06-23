package com.example.evstation.batteryswap.infrastructure.jpa;

import com.example.evstation.batteryswap.domain.BatterySwapStatus;
import com.example.evstation.batteryswap.domain.PaymentStatus;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "battery_swap_reservation")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatterySwapReservationEntity {

    @Id
    @Column(columnDefinition = "UUID")
    @Builder.Default
    private UUID id = UUID.randomUUID();

    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;

    @Column(name = "station_id", nullable = false, columnDefinition = "UUID")
    private UUID stationId;

    @Column(name = "pile_id", columnDefinition = "UUID")
    private UUID pileId;

    @Column(name = "slot_id", columnDefinition = "UUID")
    private UUID slotId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private BatterySwapStatus status = BatterySwapStatus.RESERVED;

    @Column(name = "reserved_slot_at")
    private Instant reservedSlotAt;

    @Column(name = "requested_battery_percent", nullable = false)
    @Builder.Default
    private Integer requestedBatteryPercent = 20;

    @Column(name = "battery_capacity_kwh", nullable = false)
    @Builder.Default
    private BigDecimal batteryCapacityKwh = BigDecimal.valueOf(60.0);

    @Column(name = "estimated_ready_at")
    private Instant estimatedReadyAt;

    @Column(columnDefinition = "TEXT")
    private String note;

    @Column(name = "reserved_at", nullable = false)
    private Instant reservedAt;

    @Column(name = "started_at")
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    /**
     * Thời điểm user xác nhận đã đến trạm.
     * Hold time 15 phút tính từ đây, không phải từ reservedSlotAt.
     */
    @Column(name = "confirmed_arrival_at")
    private Instant confirmedArrivalAt;

    /**
     * Mã swap code do admin/hệ thống tạo khi user đến trạm và payment đã hoàn tất.
     * User nhập mã này vào Hardware Simulator để xác nhận đổi pin.
     */
    @Column(name = "swap_code")
    private String swapCode;

    /**
     * Thời điểm hết hạn để thực hiện swap (appointment + 15 phút).
     * Nếu quá deadline mà chưa swap -> auto cancel, auto refund.
     */
    @Column(name = "swap_deadline_at")
    private Instant swapDeadlineAt;

    @Column(name = "base_price_vnd", nullable = false)
    @Builder.Default
    private Long basePriceVnd = 5000L;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_status", nullable = false)
    @Builder.Default
    private PaymentStatus paymentStatus = PaymentStatus.UNPAID;

    /**
     * ID of the voucher redemption applied to this reservation.
     * Set when a FREE_SERVICE/BATTERY_SWAP voucher covers the full or partial cost.
     */
    @Column(name = "voucher_redemption_id", columnDefinition = "UUID")
    private UUID voucherRedemptionId;

    /**
     * Discount amount in VND applied via voucher.
     * Set when a voucher is applied via /api/ev/vouchers/redemptions/{id}/apply-to-swap.
     * If >= basePriceVnd, the user pays nothing (free swap).
     */
    @Column(name = "discount_amount_vnd")
    private Integer discountAmountVnd;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    protected void onCreate() {
        Instant now = Instant.now();
        if (id == null) {
            id = UUID.randomUUID();
        }
        if (reservedAt == null) {
            reservedAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
