/// Collaborator Profile Model
/// 
/// Represents a collaborator profile with all related information
class CollaboratorProfile {
  final String id;
  final String userAccountId;
  final String? email;
  final String? fullName;
  final String? phone;
  final DateTime? createdAt;
  final bool? hasActiveContract;
  final CollaboratorLocation? location;

  CollaboratorProfile({
    required this.id,
    required this.userAccountId,
    this.email,
    this.fullName,
    this.phone,
    this.createdAt,
    this.hasActiveContract,
    this.location,
  });

  factory CollaboratorProfile.fromJson(Map<String, dynamic> json) {
    return CollaboratorProfile(
      id: json['id'] as String,
      userAccountId: json['userAccountId'] as String,
      email: json['email'] as String?,
      fullName: json['fullName'] as String?,
      phone: json['phone'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      hasActiveContract: json['hasActiveContract'] as bool?,
      location: json['location'] != null
          ? CollaboratorLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userAccountId': userAccountId,
      if (email != null) 'email': email,
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (hasActiveContract != null) 'hasActiveContract': hasActiveContract,
      if (location != null) 'location': location!.toJson(),
    };
  }
}

/// Collaborator Location Model
class CollaboratorLocation {
  final double? lat;
  final double? lng;
  final DateTime? updatedAt;
  final String? source;

  CollaboratorLocation({
    this.lat,
    this.lng,
    this.updatedAt,
    this.source,
  });

  factory CollaboratorLocation.fromJson(Map<String, dynamic> json) {
    return CollaboratorLocation(
      lat: json['lat'] != null ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] != null ? (json['lng'] as num).toDouble() : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (source != null) 'source': source,
    };
  }
}

/// Create Collaborator Request Model
class CreateCollaboratorRequest {
  final String userAccountId;
  final String? fullName;
  final String? phone;

  CreateCollaboratorRequest({
    required this.userAccountId,
    this.fullName,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'userAccountId': userAccountId,
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
    };
  }
}

