/// Admin Change Request Model
/// 
/// Represents a change request with all admin-specific fields
class AdminChangeRequest {
  final String id;
  final ChangeRequestType type;
  final ChangeRequestStatus status;
  final String? stationId;
  final String? proposedStationVersionId;
  final String? submittedBy;
  final String? submitterEmail;
  final int? riskScore;
  final List<String> riskReasons;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final bool? hasVerificationTask;
  final bool? hasPassedVerification;
  final StationData? stationData;
  final List<AuditLog> auditLogs;

  AdminChangeRequest({
    required this.id,
    required this.type,
    required this.status,
    this.stationId,
    this.proposedStationVersionId,
    this.submittedBy,
    this.submitterEmail,
    this.riskScore,
    this.riskReasons = const [],
    this.adminNote,
    this.createdAt,
    this.submittedAt,
    this.decidedAt,
    this.hasVerificationTask,
    this.hasPassedVerification,
    this.stationData,
    this.auditLogs = const [],
  });

  factory AdminChangeRequest.fromJson(Map<String, dynamic> json) {
    return AdminChangeRequest(
      id: json['id'] as String,
      type: ChangeRequestType.fromString(json['type'] as String),
      status: ChangeRequestStatus.fromString(json['status'] as String),
      stationId: json['stationId'] as String?,
      proposedStationVersionId: json['proposedStationVersionId'] as String?,
      submittedBy: json['submittedBy'] as String?,
      submitterEmail: json['submitterEmail'] as String?,
      riskScore: json['riskScore'] as int?,
      riskReasons: (json['riskReasons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      adminNote: json['adminNote'] as String?,
      hasVerificationTask: json['hasVerificationTask'] as bool?,
      hasPassedVerification: json['hasPassedVerification'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      decidedAt: json['decidedAt'] != null
          ? DateTime.parse(json['decidedAt'] as String)
          : null,
      stationData: json['stationData'] != null
          ? StationData.fromJson(json['stationData'] as Map<String, dynamic>)
          : null,
      auditLogs: (json['auditLogs'] as List<dynamic>?)
              ?.map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isPending => status == ChangeRequestStatus.pending;
  bool get isApproved => status == ChangeRequestStatus.approved;
  bool get isRejected => status == ChangeRequestStatus.rejected;
  bool get isPublished => status == ChangeRequestStatus.published;
  bool get canApprove => isPending;
  bool get canReject => isPending;
  
  /// Check if change request can be published
  /// For high-risk CRs (riskScore >= 60), requires verification task PASS
  bool get canPublish {
    if (!isApproved) return false;
    
    // If risk score >= 60, must have verification task and it must be PASS
    if (riskScore != null && riskScore! >= 60) {
      return hasPassedVerification == true;
    }
    
    return true;
  }
  
  /// Check if this is a high-risk change request
  bool get isHighRisk => riskScore != null && riskScore! >= 60;
  
  /// Get verification status message for UI
  String? get verificationStatusMessage {
    if (!isHighRisk) return null;
    
    if (hasPassedVerification == true) {
      return '✓ Verification passed';
    }
    
    if (hasVerificationTask == true) {
      return '⏳ Verification task pending';
    }
    
    return '⚠️ Verification task required';
  }
}

enum ChangeRequestType {
  createStation,
  updateStation;

  static ChangeRequestType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CREATE_STATION':
        return ChangeRequestType.createStation;
      case 'UPDATE_STATION':
        return ChangeRequestType.updateStation;
      default:
        return ChangeRequestType.updateStation;
    }
  }

  String get displayName {
    switch (this) {
      case ChangeRequestType.createStation:
        return 'Create Station';
      case ChangeRequestType.updateStation:
        return 'Update Station';
    }
  }
}

enum ChangeRequestStatus {
  draft,
  pending,
  approved,
  rejected,
  published;

  static ChangeRequestStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DRAFT':
        return ChangeRequestStatus.draft;
      case 'PENDING':
        return ChangeRequestStatus.pending;
      case 'APPROVED':
        return ChangeRequestStatus.approved;
      case 'REJECTED':
        return ChangeRequestStatus.rejected;
      case 'PUBLISHED':
        return ChangeRequestStatus.published;
      default:
        return ChangeRequestStatus.draft;
    }
  }

  String get displayName {
    switch (this) {
      case ChangeRequestStatus.draft:
        return 'Draft';
      case ChangeRequestStatus.pending:
        return 'Pending';
      case ChangeRequestStatus.approved:
        return 'Approved';
      case ChangeRequestStatus.rejected:
        return 'Rejected';
      case ChangeRequestStatus.published:
        return 'Published';
    }
  }
}

class StationData {
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? operatingHours;
  final String? parking;
  final String? visibility;
  final String? publicStatus;
  final List<Service> services;

  StationData({
    this.name,
    this.address,
    this.lat,
    this.lng,
    this.operatingHours,
    this.parking,
    this.visibility,
    this.publicStatus,
    this.services = const [],
  });

  factory StationData.fromJson(Map<String, dynamic> json) {
    return StationData(
      name: json['name'] as String?,
      address: json['address'] as String?,
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      operatingHours: json['operatingHours'] as String?,
      parking: json['parking'] as String?,
      visibility: json['visibility'] as String?,
      publicStatus: json['publicStatus'] as String?,
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => Service.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Service {
  final String type;
  final List<ChargingPort> chargingPorts;

  Service({
    required this.type,
    this.chargingPorts = const [],
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      type: json['type'] as String,
      chargingPorts: (json['chargingPorts'] as List<dynamic>?)
              ?.map((e) => ChargingPort.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ChargingPort {
  final String? powerType;
  final double? powerKw;
  final int? count;

  ChargingPort({
    this.powerType,
    this.powerKw,
    this.count,
  });

  factory ChargingPort.fromJson(Map<String, dynamic> json) {
    return ChargingPort(
      powerType: json['powerType'] as String?,
      powerKw: json['powerKw'] != null
          ? (json['powerKw'] as num).toDouble()
          : null,
      count: json['count'] as int?,
    );
  }
}

class AuditLog {
  final String action;
  final String? actorId;
  final String? actorRole;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  AuditLog({
    required this.action,
    this.actorId,
    this.actorRole,
    this.createdAt,
    this.metadata,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      action: json['action'] as String,
      actorId: json['actorId'] as String?,
      actorRole: json['actorRole'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

