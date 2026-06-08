/// Battery Swap Change Request Model
/// 
/// Represents a change request for battery swap stations
class BatterySwapChangeRequest {
  final String id;
  final BatterySwapCRType type;
  final BatterySwapCRStatus status;
  final String stationId;
  final String? stationName;
  final String? submittedBy;
  final String? submittedByEmail;
  final int? riskScore;
  final List<String> riskReasons;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? decidedAt;

  // Station version fields
  final String? versionId;
  final int? versionNo;
  final String? workflowStatus;
  final int? totalBatteries;
  final double? avgChargePowerKw;
  final String? operatingHours;
  final double? parkingFee;
  final String? note;
  final DateTime? publishedAt;

  // Pile/slot layout
  final List<BatterySwapPileTemplate>? pileTemplates;

  // Risk flags
  final bool requiresVerification;
  final bool requiresAdminReview;

  // Computed properties
  bool get isHighRisk => riskScore != null && riskScore! >= 60;
  bool get canApprove =>
      status == BatterySwapCRStatus.pending && !requiresAdminReview;
  bool get canReject => status == BatterySwapCRStatus.pending;
  bool get canPublish =>
      status == BatterySwapCRStatus.approved && !requiresVerification;

  BatterySwapChangeRequest({
    required this.id,
    required this.type,
    required this.status,
    String? stationId,
    this.stationName,
    this.submittedBy,
    this.submittedByEmail,
    this.riskScore,
    this.riskReasons = const [],
    this.adminNote,
    required DateTime createdAt,
    this.submittedAt,
    this.decidedAt,
    this.versionId,
    this.versionNo,
    this.workflowStatus,
    this.totalBatteries,
    this.avgChargePowerKw,
    this.operatingHours,
    this.parkingFee,
    this.note,
    this.publishedAt,
    this.pileTemplates,
    this.requiresVerification = false,
    this.requiresAdminReview = false,
  }) : stationId = stationId ?? '',
       createdAt = createdAt;

  factory BatterySwapChangeRequest.fromJson(Map<String, dynamic> json) {
    return BatterySwapChangeRequest(
      id: json['id'] as String,
      type: BatterySwapCRType.fromString(json['type'] as String? ?? 'UPDATE'),
      status:
          BatterySwapCRStatus.fromString(json['status'] as String? ?? 'PENDING'),
      stationId: json['stationId'] as String?,
      stationName: json['stationName'] as String?,
      submittedBy: json['submittedBy'] as String?,
      submittedByEmail: json['submittedByEmail'] as String?,
      riskScore: (json['riskScore'] as num?)?.toInt(),
      riskReasons: (json['riskReasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      adminNote: json['adminNote'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      decidedAt: json['decidedAt'] != null
          ? DateTime.parse(json['decidedAt'] as String)
          : null,
      versionId: json['versionId'] as String?,
      versionNo: (json['versionNo'] as num?)?.toInt(),
      workflowStatus: json['workflowStatus'] as String?,
      totalBatteries: (json['totalBatteries'] as num?)?.toInt(),
      avgChargePowerKw: (json['avgChargePowerKw'] as num?)?.toDouble(),
      operatingHours: json['operatingHours'] as String?,
      parkingFee: (json['parkingFee'] as num?)?.toDouble(),
      note: json['note'] as String?,
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      pileTemplates: (json['pileTemplates'] as List<dynamic>?)
          ?.map((e) => BatterySwapPileTemplate.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiresVerification:
          json['requiresVerification'] as bool? ?? false,
      requiresAdminReview: json['requiresAdminReview'] as bool? ?? false,
    );
  }
}

enum BatterySwapCRType {
  create,
  update,
  delete;

  static BatterySwapCRType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CREATE':
      case 'CREATE_BATTERY_SWAP_STATION':
        return BatterySwapCRType.create;
      case 'UPDATE':
      case 'UPDATE_BATTERY_SWAP_STATION':
        return BatterySwapCRType.update;
      case 'DELETE':
        return BatterySwapCRType.delete;
      default:
        return BatterySwapCRType.update;
    }
  }

  String get displayName {
    switch (this) {
      case BatterySwapCRType.create:
        return 'Create';
      case BatterySwapCRType.update:
        return 'Update';
      case BatterySwapCRType.delete:
        return 'Delete';
    }
  }
}

enum BatterySwapCRStatus {
  draft,
  pending,
  approved,
  rejected,
  published;

  static BatterySwapCRStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DRAFT':
        return BatterySwapCRStatus.draft;
      case 'PENDING':
        return BatterySwapCRStatus.pending;
      case 'APPROVED':
        return BatterySwapCRStatus.approved;
      case 'REJECTED':
        return BatterySwapCRStatus.rejected;
      case 'PUBLISHED':
        return BatterySwapCRStatus.published;
      default:
        return BatterySwapCRStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case BatterySwapCRStatus.draft:
        return 'Draft';
      case BatterySwapCRStatus.pending:
        return 'Pending';
      case BatterySwapCRStatus.approved:
        return 'Approved';
      case BatterySwapCRStatus.rejected:
        return 'Rejected';
      case BatterySwapCRStatus.published:
        return 'Published';
    }
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
              ?.map((e) =>
                  BatterySwapSlotTemplate.fromJson(e as Map<String, dynamic>))
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

/// Risk level enum for filtering
enum BatterySwapRiskLevel {
  low,
  medium,
  high,
  requiredVerification;

  static BatterySwapRiskLevel? fromScore(int? score) {
    if (score == null) return null;
    if (score >= 60) return BatterySwapRiskLevel.requiredVerification;
    if (score >= 30) return BatterySwapRiskLevel.high;
    if (score >= 15) return BatterySwapRiskLevel.medium;
    return BatterySwapRiskLevel.low;
  }

  String get displayName {
    switch (this) {
      case BatterySwapRiskLevel.low:
        return 'Low';
      case BatterySwapRiskLevel.medium:
        return 'Medium';
      case BatterySwapRiskLevel.high:
        return 'High';
      case BatterySwapRiskLevel.requiredVerification:
        return 'Required Verification';
    }
  }
}
