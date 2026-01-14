/// Admin Station Model
/// 
/// Represents a station with all admin-specific fields
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
      stationId: json['stationId'] as String,
      providerId: json['providerId'] as String?,
      providerEmail: json['providerEmail'] as String?,
      stationCreatedAt: json['stationCreatedAt'] != null
          ? DateTime.parse(json['stationCreatedAt'] as String)
          : null,
      publishedVersionId: json['publishedVersionId'] as String?,
      publishedVersionNo: json['publishedVersionNo'] as int?,
      workflowStatus: json['workflowStatus'] != null
          ? WorkflowStatus.fromString(json['workflowStatus'] as String)
          : null,
      name: json['name'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      operatingHours: json['operatingHours'] as String?,
      parking: json['parking'] != null
          ? ParkingType.fromString(json['parking'] as String)
          : null,
      visibility: json['visibility'] != null
          ? VisibilityType.fromString(json['visibility'] as String)
          : null,
      publicStatus: json['publicStatus'] != null
          ? PublicStatus.fromString(json['publicStatus'] as String)
          : null,
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      createdBy: json['createdBy'] as String?,
      createdByEmail: json['createdByEmail'] as String?,
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => Service.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trustScore: json['trustScore'] as int?,
      totalVersions: json['totalVersions'] as int? ?? 0,
      activeBookings: json['activeBookings'] as int? ?? 0,
    );
  }

  bool get isPublished => workflowStatus == WorkflowStatus.published;
  bool get hasActiveBookings => activeBookings > 0;
}

class Service {
  final ServiceType type;
  final List<ChargingPort> chargingPorts;

  Service({
    required this.type,
    this.chargingPorts = const [],
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      type: ServiceType.fromString(json['type'] as String),
      chargingPorts: (json['chargingPorts'] as List<dynamic>?)
              ?.map((e) => ChargingPort.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
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
      powerType: PowerType.fromString(json['powerType'] as String),
      powerKw: (json['powerKw'] as num?)?.toDouble(),
      portCount: json['portCount'] as int? ?? 0,
    );
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
    return ServiceType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase().replaceAll('_', ''),
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

