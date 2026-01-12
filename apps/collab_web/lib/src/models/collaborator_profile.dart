/// Collaborator Profile Model
class CollaboratorProfile {
  final String id;
  final String userAccountId;
  final String email;
  final String? name;
  final String? phone;
  final CollaboratorLocation? location;

  CollaboratorProfile({
    required this.id,
    required this.userAccountId,
    required this.email,
    this.name,
    this.phone,
    this.location,
  });

  factory CollaboratorProfile.fromJson(Map<String, dynamic> json) {
    return CollaboratorProfile(
      id: json['id'] as String? ?? '',
      userAccountId: json['userAccountId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['fullName'] as String? ?? json['name'] as String?,
      phone: json['phone'] as String?,
      location: json['location'] != null 
          ? CollaboratorLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userAccountId': userAccountId,
      'email': email,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (location != null) 'location': location!.toJson(),
    };
  }

  /// Get display name (name or email prefix)
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return email.split('@').first;
  }

  /// Get initial for avatar
  String get initial {
    final display = displayName;
    if (display.isNotEmpty) {
      return display[0].toUpperCase();
    }
    return 'U';
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
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
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

  bool get hasLocation => lat != null && lng != null;
}

