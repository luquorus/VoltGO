import 'package:flutter/foundation.dart';

@immutable
class SimulatorSlotModel {
  final String slotId;
  final int slotIndex;
  final String? batteryId;
  final int batteryChargePercent;
  final String status;
  final DateTime? estimatedFullAt;
  final DateTime updatedAt;

  const SimulatorSlotModel({
    required this.slotId,
    required this.slotIndex,
    this.batteryId,
    required this.batteryChargePercent,
    required this.status,
    this.estimatedFullAt,
    required this.updatedAt,
  });

  factory SimulatorSlotModel.fromJson(Map<String, dynamic> json) {
    return SimulatorSlotModel(
      slotId: json['slotId'] as String,
      slotIndex: json['slotIndex'] as int,
      batteryId: json['batteryId'] as String?,
      batteryChargePercent: json['batteryChargePercent'] as int,
      status: json['status'] as String,
      estimatedFullAt: json['estimatedFullAt'] != null
          ? DateTime.parse(json['estimatedFullAt'] as String)
          : null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  SimulatorSlotModel copyWith({
    String? slotId,
    int? slotIndex,
    String? batteryId,
    int? batteryChargePercent,
    String? status,
    DateTime? estimatedFullAt,
    DateTime? updatedAt,
  }) {
    return SimulatorSlotModel(
      slotId: slotId ?? this.slotId,
      slotIndex: slotIndex ?? this.slotIndex,
      batteryId: batteryId ?? this.batteryId,
      batteryChargePercent: batteryChargePercent ?? this.batteryChargePercent,
      status: status ?? this.status,
      estimatedFullAt: estimatedFullAt ?? this.estimatedFullAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class SimulatorPileModel {
  final String pileId;
  final int pileIndex;
  final String status;
  final List<SimulatorSlotModel> slots;

  const SimulatorPileModel({
    required this.pileId,
    required this.pileIndex,
    required this.status,
    required this.slots,
  });

  factory SimulatorPileModel.fromJson(Map<String, dynamic> json) {
    return SimulatorPileModel(
      pileId: json['pileId'] as String,
      pileIndex: json['pileIndex'] as int,
      status: json['status'] as String,
      slots: (json['slots'] as List<dynamic>)
          .map((e) => SimulatorSlotModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  SimulatorPileModel copyWith({
    String? pileId,
    int? pileIndex,
    String? status,
    List<SimulatorSlotModel>? slots,
  }) {
    return SimulatorPileModel(
      pileId: pileId ?? this.pileId,
      pileIndex: pileIndex ?? this.pileIndex,
      status: status ?? this.status,
      slots: slots ?? this.slots,
    );
  }
}

@immutable
class SimulatorStationPilesModel {
  final String stationId;
  final String stationName;
  final List<SimulatorPileModel> piles;

  const SimulatorStationPilesModel({
    required this.stationId,
    required this.stationName,
    required this.piles,
  });

  factory SimulatorStationPilesModel.fromJson(Map<String, dynamic> json) {
    return SimulatorStationPilesModel(
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      piles: (json['piles'] as List<dynamic>)
          .map((e) => SimulatorPileModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@immutable
class SimulatorStationListItem {
  final String stationId;
  final String? name;

  const SimulatorStationListItem({
    required this.stationId,
    this.name,
  });

  factory SimulatorStationListItem.fromJson(Map<String, dynamic> json) {
    return SimulatorStationListItem(
      stationId: json['stationId'] as String,
      name: json['name'] as String?,
    );
  }
}
