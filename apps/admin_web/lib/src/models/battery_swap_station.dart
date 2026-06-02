/// Battery Swap Station Model
///
/// Represents a battery swap station with its published version info.
class BatterySwapStation {
  final String id;
  final String? providerId;
  final String? providerEmail;
  final DateTime? stationCreatedAt;

  // Published version info
  final String? publishedVersionId;
  final int? publishedVersionNo;
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? operatingHours;
  final String? workflowStatus;
  final String? publicStatus;
  final DateTime? publishedAt;
  final String? createdBy;
  final String? createdByEmail;

  // Battery swap specific fields
  final int? totalBatteries;
  final int? availableBatteries;
  final double? avgChargePowerKw;
  final double? basePriceVnd;
  final int? totalPiles;
  final int? totalSlots;
  final int? availableSlots;
  final String? parkingFee;

  // Trust score
  final int? trustScore;
  final String? trustLevel;

  // Stats
  final int totalVersions;
  final int pendingCRs;

  BatterySwapStation({
    required this.id,
    this.providerId,
    this.providerEmail,
    this.stationCreatedAt,
    this.publishedVersionId,
    this.publishedVersionNo,
    this.name,
    this.address,
    this.lat,
    this.lng,
    this.operatingHours,
    this.workflowStatus,
    this.publicStatus,
    this.publishedAt,
    this.createdBy,
    this.createdByEmail,
    this.totalBatteries,
    this.availableBatteries,
    this.avgChargePowerKw,
    this.basePriceVnd,
    this.totalPiles,
    this.totalSlots,
    this.availableSlots,
    this.parkingFee,
    this.trustScore,
    this.trustLevel,
    this.totalVersions = 0,
    this.pendingCRs = 0,
  });

  factory BatterySwapStation.fromJson(Map<String, dynamic> json) {
    return BatterySwapStation(
      id: json['id'] as String,
      providerId: json['providerId'] as String?,
      providerEmail: json['providerEmail'] as String?,
      stationCreatedAt: json['stationCreatedAt'] != null
          ? DateTime.parse(json['stationCreatedAt'] as String)
          : null,
      publishedVersionId: json['publishedVersionId'] as String?,
      publishedVersionNo: json['publishedVersionNo'] as int?,
      name: json['name'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      operatingHours: json['operatingHours'] as String?,
      workflowStatus: json['workflowStatus'] as String?,
      publicStatus: json['publicStatus'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      createdBy: json['createdBy'] as String?,
      createdByEmail: json['createdByEmail'] as String?,
      totalBatteries: json['totalBatteries'] as int?,
      availableBatteries: json['availableBatteries'] as int?,
      avgChargePowerKw: (json['avgChargePowerKw'] as num?)?.toDouble(),
      basePriceVnd: (json['basePriceVnd'] as num?)?.toDouble(),
      totalPiles: json['totalPiles'] as int?,
      totalSlots: json['totalSlots'] as int?,
      availableSlots: json['availableSlots'] as int?,
      parkingFee: json['parkingFee'] as String?,
      trustScore: json['trustScore'] as int?,
      trustLevel: json['trustLevel'] as String?,
      totalVersions: json['totalVersions'] as int? ?? 0,
      pendingCRs: json['pendingCRs'] as int? ?? 0,
    );
  }

  bool get isPublished => workflowStatus == 'PUBLISHED';
  bool get hasPendingCRs => pendingCRs > 0;
}

/// Battery Swap Station with full version details (for detail screen)
class BatterySwapStationDetail extends BatterySwapStation {
  final List<BatterySwapPileTemplate>? pileTemplates;
  final String? note;

  BatterySwapStationDetail({
    required super.id,
    super.providerId,
    super.providerEmail,
    super.stationCreatedAt,
    super.publishedVersionId,
    super.publishedVersionNo,
    super.name,
    super.address,
    super.lat,
    super.lng,
    super.operatingHours,
    super.workflowStatus,
    super.publicStatus,
    super.publishedAt,
    super.createdBy,
    super.createdByEmail,
    super.totalBatteries,
    super.availableBatteries,
    super.avgChargePowerKw,
    super.basePriceVnd,
    super.totalPiles,
    super.totalSlots,
    super.availableSlots,
    super.parkingFee,
    super.trustScore,
    super.trustLevel,
    super.totalVersions,
    super.pendingCRs,
    this.pileTemplates,
    this.note,
  });

  factory BatterySwapStationDetail.fromJson(Map<String, dynamic> json) {
    return BatterySwapStationDetail(
      id: json['id'] as String,
      providerId: json['providerId'] as String?,
      providerEmail: json['providerEmail'] as String?,
      stationCreatedAt: json['stationCreatedAt'] != null
          ? DateTime.parse(json['stationCreatedAt'] as String)
          : null,
      publishedVersionId: json['publishedVersionId'] as String?,
      publishedVersionNo: json['publishedVersionNo'] as int?,
      name: json['name'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      operatingHours: json['operatingHours'] as String?,
      workflowStatus: json['workflowStatus'] as String?,
      publicStatus: json['publicStatus'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      createdBy: json['createdBy'] as String?,
      createdByEmail: json['createdByEmail'] as String?,
      totalBatteries: json['totalBatteries'] as int?,
      availableBatteries: json['availableBatteries'] as int?,
      avgChargePowerKw: (json['avgChargePowerKw'] as num?)?.toDouble(),
      basePriceVnd: (json['basePriceVnd'] as num?)?.toDouble(),
      totalPiles: json['totalPiles'] as int?,
      totalSlots: json['totalSlots'] as int?,
      availableSlots: json['availableSlots'] as int?,
      parkingFee: json['parkingFee'] as String?,
      trustScore: json['trustScore'] as int?,
      trustLevel: json['trustLevel'] as String?,
      totalVersions: json['totalVersions'] as int? ?? 0,
      pendingCRs: json['pendingCRs'] as int? ?? 0,
      pileTemplates: (json['pileTemplates'] as List<dynamic>?)
          ?.map((e) => BatterySwapPileTemplate.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: json['note'] as String?,
    );
  }
}

class BatterySwapPileTemplate {
  final String id;
  final int pileIndex;
  final int slotsPerPile;
  final List<BatterySwapSlotTemplate> slots;

  BatterySwapPileTemplate({
    required this.id,
    required this.pileIndex,
    required this.slotsPerPile,
    required this.slots,
  });

  factory BatterySwapPileTemplate.fromJson(Map<String, dynamic> json) {
    return BatterySwapPileTemplate(
      id: json['id'] as String,
      pileIndex: (json['pileIndex'] as num?)?.toInt() ?? 0,
      slotsPerPile: (json['slotsPerPile'] as num?)?.toInt() ?? 0,
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) => BatterySwapSlotTemplate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BatterySwapSlotTemplate {
  final String id;
  final int slotIndex;
  final double? batteryCapacityKwh;

  BatterySwapSlotTemplate({
    required this.id,
    required this.slotIndex,
    this.batteryCapacityKwh,
  });

  factory BatterySwapSlotTemplate.fromJson(Map<String, dynamic> json) {
    return BatterySwapSlotTemplate(
      id: json['id'] as String,
      slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
      batteryCapacityKwh: (json['batteryCapacityKwh'] as num?)?.toDouble(),
    );
  }
}
