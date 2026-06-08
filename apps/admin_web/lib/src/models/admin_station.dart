/// Admin Station Model
/// 
/// Represents a station with all admin-specific fields
/// Maps to backend AdminStationDTO
class AdminStation {
  final String stationId;
  final String? providerId;
  final String? providerEmail;
  final DateTime? stationCreatedAt;
  
  // Current published version info
  final String? publishedVersionId;
  final int? publishedVersionNo;
  final WorkflowStatus? workflowStatus;
  final String? name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? operatingHours;
  final ParkingType? parking;
  final VisibilityType? visibility;
  final PublicStatus? publicStatus;
  final DateTime? publishedAt;
  final String? createdBy;
  final String? createdByEmail;
  
  // Services and ports
  final List<Service> services;
  
  // Trust score
  final int? trustScore;
  
  // Statistics
  final int totalVersions;
  final int activeBookings;

  AdminStation({
    required this.stationId,
    this.providerId,
    this.providerEmail,
    this.stationCreatedAt,
    this.publishedVersionId,
    this.publishedVersionNo,
    this.workflowStatus,
    this.name,
    this.address,
    this.lat,
    this.lng,
    this.operatingHours,
    this.parking,
    this.visibility,
    this.publicStatus,
    this.publishedAt,
    this.createdBy,
    this.createdByEmail,
    this.services = const [],
    this.trustScore,
    this.totalVersions = 0,
    this.activeBookings = 0,
  });

  factory AdminStation.fromJson(Map<String, dynamic> json) {
    return AdminStation(
      stationId: (json['stationId'] as String?) ?? '',
      providerId: json['providerId'] as String?,
      providerEmail: json['providerEmail'] as String?,
      stationCreatedAt: _parseDateTime(json['stationCreatedAt']),
      publishedVersionId: json['publishedVersionId'] as String?,
      publishedVersionNo: json['publishedVersionNo'] as int?,
      workflowStatus: _parseEnum(json['workflowStatus'], WorkflowStatus.fromString),
      name: json['name'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      operatingHours: json['operatingHours'] as String?,
      parking: _parseEnum(json['parking'], ParkingType.fromString),
      visibility: _parseEnum(json['visibility'], VisibilityType.fromString),
      publicStatus: _parseEnum(json['publicStatus'], PublicStatus.fromString),
      publishedAt: _parseDateTime(json['publishedAt']),
      createdBy: json['createdBy'] as String?,
      createdByEmail: json['createdByEmail'] as String?,
      services: _parseList(json['services'], Service.fromJson),
      trustScore: json['trustScore'] as int?,
      totalVersions: (json['totalVersions'] as num?)?.toInt() ?? 0,
      activeBookings: (json['activeBookings'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static T? _parseEnum<T>(dynamic value, T Function(String) fromString) {
    if (value == null) return null;
    if (value is T) return value;
    if (value is String) return fromString(value);
    return null;
  }

  static List<T> _parseList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  bool get isPublished => workflowStatus == WorkflowStatus.published;
  bool get hasActiveBookings => activeBookings > 0;
}

class Service {
  final ServiceType type;
  final List<ChargingPort> chargingPorts;
  final int? totalBatteries;
  final double? avgChargePowerKw;

  Service({
    required this.type,
    this.chargingPorts = const [],
    this.totalBatteries,
    this.avgChargePowerKw,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      type: _parseEnum(json['type'], ServiceType.fromString) ?? ServiceType.charging,
      chargingPorts: _parseList(json['chargingPorts'], ChargingPort.fromJson),
      totalBatteries: json['totalBatteries'] as int?,
      avgChargePowerKw: (json['avgChargePowerKw'] as num?)?.toDouble(),
    );
  }

  static T? _parseEnum<T>(dynamic value, T Function(String) fromString) {
    if (value == null) return null;
    if (value is T) return value;
    if (value is String) return fromString(value);
    return null;
  }

  static List<T> _parseList<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

class ChargingPort {
  final PowerType powerType;
  final double? powerKw;
  final int portCount;

  ChargingPort({
    required this.powerType,
    this.powerKw,
    required this.portCount,
  });

  factory ChargingPort.fromJson(Map<String, dynamic> json) {
    return ChargingPort(
      powerType: _parseEnum(json['powerType'], PowerType.fromString) ?? PowerType.dc,
      powerKw: (json['powerKw'] as num?)?.toDouble(),
      portCount: (json['portCount'] as num?)?.toInt() ?? 0,
    );
  }

  static T? _parseEnum<T>(dynamic value, T Function(String) fromString) {
    if (value == null) return null;
    if (value is T) return value;
    if (value is String) return fromString(value);
    return null;
  }
}

// Enums
enum WorkflowStatus {
  draft,
  pending,
  published,
  rejected,
  archived;

  static WorkflowStatus fromString(String value) {
    return WorkflowStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => WorkflowStatus.draft,
    );
  }
}

enum ParkingType {
  paid,
  free,
  unknown;

  static ParkingType fromString(String value) {
    return ParkingType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => ParkingType.unknown,
    );
  }
}

enum VisibilityType {
  public,
  private,
  restricted;

  static VisibilityType fromString(String value) {
    return VisibilityType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => VisibilityType.public,
    );
  }
}

enum PublicStatus {
  active,
  inactive,
  maintenance;

  static PublicStatus fromString(String value) {
    return PublicStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => PublicStatus.active,
    );
  }
}

enum ServiceType {
  charging,
  batterySwap;

  static ServiceType fromString(String value) {
    final normalized = value.toUpperCase().replaceAll('_', '');
    return ServiceType.values.firstWhere(
      (e) => e.name.toUpperCase() == normalized,
      orElse: () => ServiceType.charging,
    );
  }
}

enum PowerType {
  dc,
  ac;

  static PowerType fromString(String value) {
    return PowerType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => PowerType.dc,
    );
  }
}
