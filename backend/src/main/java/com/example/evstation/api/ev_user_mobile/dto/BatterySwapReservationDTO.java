package com.example.evstation.api.ev_user_mobile.dto;

import com.example.evstation.batteryswap.domain.BatterySwapStatus;
import com.example.evstation.batteryswap.domain.PaymentStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

/**
 * Đơn đặt đổi pin của EV user / staff.
 */
@Data
@Builder
public class BatterySwapReservationDTO {
    private UUID id;
    private UUID stationId;
    private String stationName;
    private UUID pileId;
    private Integer pileIndex;
    private UUID slotId;
    private Integer slotIndex;
    /**
     * % pin trong slot hiện tại. User bắt đầu swap khi pin này đạt 100%.
     */
    private Integer slotBatteryChargePercent;
    /**
     * Trạng thái hiện tại của slot — dùng để hiển thị "Your slot is ready!" khi chuyển sang AVAILABLE.
     */
    private String slotStatus;
    private BatterySwapStatus status;
    private PaymentStatus paymentStatus;
    private Long basePriceVnd;
    private Instant reservedSlotAt;
    private Integer requestedBatteryPercent;
    private BigDecimal batteryCapacityKwh;
    private Instant estimatedReadyAt;
    private Instant reservedAt;
    private Instant startedAt;
    private Instant completedAt;
    private Instant cancelledAt;
    /**
     * Thời điểm user xác nhận đã đến trạm.
     * Hold time 15 phút tính từ đây.
     */
    private Instant confirmedArrivalAt;
    private String note;
    /**
     * Mã swap code để xác nhận đổi pin tại Hardware Simulator.
     */
    private String swapCode;
    /**
     * Thời điểm hết hạn swap (appointment + 15 phút).
     */
    private Instant swapDeadlineAt;
    /**
     * ID của voucher redemption đã apply cho reservation này.
     * Được set khi user apply voucher FREE_SERVICE cho battery swap.
     */
    private UUID voucherRedemptionId;
    /**
     * Số tiền giảm giá (VND) từ voucher.
     * Nếu >= basePriceVnd thì user không cần thanh toán (swap miễn phí).
     */
    private Integer discountAmountVnd;
    private StationStateDTO stationState;

    @Data
    @Builder
    public static class StationStateDTO {
        private Integer totalBatteries;
        private Integer availableBatteries;
        private BigDecimal avgChargePowerKw;
    }
}
