import 'package:flutter/foundation.dart';

/// Battery slot status
enum BatterySlotStatus { available, occupied, charging, reserved, swappedOut }

/// Battery slot model
@immutable
class BatterySlotModel {
  final String slotId;
  final int slotIndex;
  final String? batteryId;
  final int batteryChargePercent;
  final BatterySlotStatus status;
  /// Thời điểm ước tính pin sẽ đầy (100%). Null nếu không đang sạc.
  final DateTime? estimatedFullAt;

  const BatterySlotModel({
    required this.slotId,
    required this.slotIndex,
    this.batteryId,
    required this.batteryChargePercent,
    required this.status,
    this.estimatedFullAt,
  });

  factory BatterySlotModel.fromJson(Map<String, dynamic> j) {
    return BatterySlotModel(
      slotId: j['slotId']?.toString() ?? '',
      slotIndex: (j['slotIndex'] as num?)?.toInt() ?? 0,
      batteryId: j['batteryId']?.toString(),
      batteryChargePercent: (j['batteryChargePercent'] as num?)?.toInt() ?? 100,
      status: _parseStatus(j['status']?.toString()),
      estimatedFullAt: j['estimatedFullAt'] != null
          ? DateTime.tryParse(j['estimatedFullAt'].toString())
          : null,
    );
  }

  /// Cập nhật từ WebSocket slot update
  BatterySlotModel copyWithSlotUpdate({
    int? batteryChargePercent,
    BatterySlotStatus? status,
    DateTime? estimatedFullAt,
  }) {
    return BatterySlotModel(
      slotId: slotId,
      slotIndex: slotIndex,
      batteryId: batteryId,
      batteryChargePercent: batteryChargePercent ?? this.batteryChargePercent,
      status: status ?? this.status,
      estimatedFullAt: estimatedFullAt ?? this.estimatedFullAt,
    );
  }

  static BatterySlotStatus _parseStatus(String? s) {
    switch (s?.toUpperCase()) {
      case 'OCCUPIED':
        return BatterySlotStatus.occupied;
      case 'CHARGING':
        return BatterySlotStatus.charging;
      case 'RESERVED':
        return BatterySlotStatus.reserved;
      case 'SWAPPED_OUT':
        return BatterySlotStatus.swappedOut;
      default:
        return BatterySlotStatus.available;
    }
  }
}

/// Swap pile model
@immutable
class SwapPileModel {
  final String pileId;
  final int pileIndex;
  final String status;
  final List<BatterySlotModel> slots;

  const SwapPileModel({
    required this.pileId,
    required this.pileIndex,
    required this.status,
    required this.slots,
  });

  /// Slots that are fully charged and ready to swap.
  int get availableSlots =>
      slots.where((s) => s.status == BatterySlotStatus.available).length;

  /// Slots that are currently charging (CHARGING or SWAPPED_OUT).
  int get chargingSlots =>
      slots.where((s) =>
          s.status == BatterySlotStatus.charging ||
          s.status == BatterySlotStatus.swappedOut).length;

  factory SwapPileModel.fromJson(Map<String, dynamic> j) {
    return SwapPileModel(
      pileId: j['pileId']?.toString() ?? '',
      pileIndex: (j['pileIndex'] as num?)?.toInt() ?? 0,
      status: j['status']?.toString() ?? 'ACTIVE',
      slots: (j['slots'] as List<dynamic>?)
              ?.map((e) => BatterySlotModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Parsed battery swap station row from `/api/ev/battery-swap/stations`.
@immutable
class BatterySwapStationModel {
  final String stationId;
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final int totalBatteries;
  final int availableBatteries;
  final double avgChargePowerKw;
  final int basePriceVnd;
  final int totalPiles;
  final int availableSlots;
  final int totalSlots;

  const BatterySwapStationModel({
    required this.stationId,
    this.name,
    this.address,
    this.lat,
    this.lng,
    this.distanceKm,
    required this.totalBatteries,
    required this.availableBatteries,
    required this.avgChargePowerKw,
    required this.basePriceVnd,
    this.totalPiles = 0,
    this.availableSlots = 0,
    this.totalSlots = 0,
  });

  factory BatterySwapStationModel.fromJson(Map<String, dynamic> j) {
    return BatterySwapStationModel(
      stationId: j['stationId']?.toString() ?? '',
      name: j['name'] as String?,
      address: j['address'] as String?,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      totalBatteries: (j['totalBatteries'] as num?)?.toInt() ?? 0,
      availableBatteries: (j['availableBatteries'] as num?)?.toInt() ?? 0,
      avgChargePowerKw: (j['avgChargePowerKw'] as num?)?.toDouble() ?? 0,
      basePriceVnd: (j['basePriceVnd'] as num?)?.toInt() ?? 5000,
      totalPiles: (j['totalPiles'] as num?)?.toInt() ?? 0,
      availableSlots: (j['availableSlots'] as num?)?.toInt() ?? 0,
      totalSlots: (j['totalSlots'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Detailed battery swap station with pile/slot info
@immutable
class BatterySwapStationDetailModel {
  final String stationId;
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? operatingHours;
  final double avgChargePowerKw;
  final int basePriceVnd;
  final int totalPiles;
  final int totalSlots;
  final int availableSlots;
  final int availableBatteries;
  final List<SwapPileModel> piles;

  const BatterySwapStationDetailModel({
    required this.stationId,
    this.name,
    this.address,
    this.lat,
    this.lng,
    this.operatingHours,
    required this.avgChargePowerKw,
    required this.basePriceVnd,
    required this.totalPiles,
    required this.totalSlots,
    required this.availableSlots,
    required this.availableBatteries,
    required this.piles,
  });

  factory BatterySwapStationDetailModel.fromJson(Map<String, dynamic> j) {
    return BatterySwapStationDetailModel(
      stationId: j['stationId']?.toString() ?? '',
      name: j['name'] as String?,
      address: j['address'] as String?,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      operatingHours: j['operatingHours'] as String?,
      avgChargePowerKw: (j['avgChargePowerKw'] as num?)?.toDouble() ?? 35,
      basePriceVnd: (j['basePriceVnd'] as num?)?.toInt() ?? 5000,
      totalPiles: (j['totalPiles'] as num?)?.toInt() ?? 0,
      totalSlots: (j['totalSlots'] as num?)?.toInt() ?? 0,
      availableSlots: (j['availableSlots'] as num?)?.toInt() ?? 0,
      availableBatteries: (j['availableBatteries'] as num?)?.toInt() ?? 0,
      piles: (j['piles'] as List<dynamic>?)
              ?.map((e) => SwapPileModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Parsed reservation from battery swap APIs.
@immutable
class BatterySwapReservationModel {
  final String id;
  final String stationId;
  final String? stationName;
  final String? pileId;
  final int? pileIndex;
  final String? slotId;
  final int? slotIndex;
  /// % pin hiện tại trong slot. User cần chờ pin đạt 100% để bắt đầu swap.
  final int? slotBatteryChargePercent;
  /// Trạng thái hiện tại của slot — dùng để hiển thị "Your slot is ready!" khi chuyển sang AVAILABLE.
  final String? slotStatus;
  final String status;
  final String paymentStatus;
  final int basePriceVnd;
  final DateTime? reservedSlotAt;
  final int requestedBatteryPercent;
  final double batteryCapacityKwh;
  final DateTime? estimatedReadyAt;
  final DateTime? reservedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  /// Thời điểm user xác nhận đã đến trạm. Bắt đầu hold timer 15 phút từ đây.
  final DateTime? confirmedArrivalAt;
  final String? note;
  /// Mã swap 4 chữ số dùng để xác thực tại trạm.
  final String? swapCode;
  /// Time the swap code expires.
  final DateTime? swapDeadlineAt;
  final String? voucherRedemptionId;
  final int? discountAmountVnd;

  const BatterySwapReservationModel({
    required this.id,
    required this.stationId,
    this.stationName,
    this.pileId,
    this.pileIndex,
    this.slotId,
    this.slotIndex,
    this.slotBatteryChargePercent,
    this.slotStatus,
    required this.status,
    required this.paymentStatus,
    required this.basePriceVnd,
    this.reservedSlotAt,
    required this.requestedBatteryPercent,
    required this.batteryCapacityKwh,
    this.estimatedReadyAt,
    this.reservedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.confirmedArrivalAt,
    this.note,
    this.swapCode,
    this.swapDeadlineAt,
    this.voucherRedemptionId,
    this.discountAmountVnd,
  });

  static DateTime? _parseInstant(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory BatterySwapReservationModel.fromJson(Map<String, dynamic> j) {
    return BatterySwapReservationModel(
      id: j['id']?.toString() ?? '',
      stationId: j['stationId']?.toString() ?? '',
      stationName: j['stationName'] as String?,
      pileId: j['pileId']?.toString(),
      pileIndex: (j['pileIndex'] as num?)?.toInt(),
      slotId: j['slotId']?.toString(),
      slotIndex: (j['slotIndex'] as num?)?.toInt(),
      slotBatteryChargePercent: (j['slotBatteryChargePercent'] as num?)?.toInt(),
      slotStatus: j['slotStatus']?.toString(),
      status: j['status']?.toString() ?? '',
      paymentStatus: j['paymentStatus']?.toString() ?? 'UNPAID',
      basePriceVnd: (j['basePriceVnd'] as num?)?.toInt() ?? 5000,
      reservedSlotAt: _parseInstant(j['reservedSlotAt']),
      requestedBatteryPercent:
          (j['requestedBatteryPercent'] as num?)?.toInt() ?? 20,
      batteryCapacityKwh:
          (j['batteryCapacityKwh'] as num?)?.toDouble() ?? 60,
      estimatedReadyAt: _parseInstant(j['estimatedReadyAt']),
      reservedAt: _parseInstant(j['reservedAt']),
      startedAt: _parseInstant(j['startedAt']),
      completedAt: _parseInstant(j['completedAt']),
      cancelledAt: _parseInstant(j['cancelledAt']),
      confirmedArrivalAt: _parseInstant(j['confirmedArrivalAt']),
      note: j['note'] as String?,
      swapCode: j['swapCode'] as String?,
      swapDeadlineAt: _parseInstant(j['swapDeadlineAt']),
      voucherRedemptionId: j['voucherRedemptionId'] as String?,
      discountAmountVnd: (j['discountAmountVnd'] as num?)?.toInt(),
    );
  }
}
