/// Collaborator Candidate for task assignment
class CollaboratorCandidate {
  final String collaboratorUserId;
  final String profileId;
  final String? fullName;
  final String? phone;
  final bool contractActive;
  final CandidateLocation? location;
  final int? distanceMeters;
  final CandidateStats stats;

  CollaboratorCandidate({
    required this.collaboratorUserId,
    required this.profileId,
    this.fullName,
    this.phone,
    required this.contractActive,
    this.location,
    this.distanceMeters,
    required this.stats,
  });

  factory CollaboratorCandidate.fromJson(Map<String, dynamic> json) {
    return CollaboratorCandidate(
      collaboratorUserId: json['collaboratorUserId'] as String? ?? '',
      profileId: json['profileId'] as String? ?? '',
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String?,
      contractActive: json['contractActive'] as bool? ?? false,
      location: json['location'] != null
          ? CandidateLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      distanceMeters: json['distanceMeters'] as int?,
      stats: json['stats'] != null
          ? CandidateStats.fromJson(json['stats'] as Map<String, dynamic>)
          : CandidateStats(completed: 0, active: 0, failedOrOverdue: 0),
    );
  }

  /// Get display name
  String get displayName => fullName ?? 'Unknown';

  /// Get distance in km (formatted)
  String get distanceKm {
    if (distanceMeters == null) return 'N/A';
    if (distanceMeters! < 1000) return '${distanceMeters}m';
    return '${(distanceMeters! / 1000).toStringAsFixed(1)}km';
  }

  /// Get initial for avatar
  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
}

/// Candidate Location
class CandidateLocation {
  final double? lat;
  final double? lng;
  final DateTime? updatedAt;
  final String? source;

  CandidateLocation({
    this.lat,
    this.lng,
    this.updatedAt,
    this.source,
  });

  factory CandidateLocation.fromJson(Map<String, dynamic> json) {
    return CandidateLocation(
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      source: json['source'] as String?,
    );
  }

  bool get hasLocation => lat != null && lng != null;
}

/// Candidate workload stats
class CandidateStats {
  final int completed;
  final int active;
  final int failedOrOverdue;

  CandidateStats({
    required this.completed,
    required this.active,
    required this.failedOrOverdue,
  });

  factory CandidateStats.fromJson(Map<String, dynamic> json) {
    return CandidateStats(
      completed: json['completed'] as int? ?? 0,
      active: json['active'] as int? ?? 0,
      failedOrOverdue: json['failedOrOverdue'] as int? ?? 0,
    );
  }
}

/// Response for candidate list
class CandidateListResponse {
  final String taskId;
  final String stationId;
  final StationLocation? stationLocation;
  final List<CollaboratorCandidate> candidates;

  CandidateListResponse({
    required this.taskId,
    required this.stationId,
    this.stationLocation,
    required this.candidates,
  });

  factory CandidateListResponse.fromJson(Map<String, dynamic> json) {
    return CandidateListResponse(
      taskId: json['taskId'] as String? ?? '',
      stationId: json['stationId'] as String? ?? '',
      stationLocation: json['stationLocation'] != null
          ? StationLocation.fromJson(json['stationLocation'] as Map<String, dynamic>)
          : null,
      candidates: (json['candidates'] as List<dynamic>?)
              ?.map((e) => CollaboratorCandidate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Station location
class StationLocation {
  final double? lat;
  final double? lng;

  StationLocation({this.lat, this.lng});

  factory StationLocation.fromJson(Map<String, dynamic> json) {
    return StationLocation(
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

