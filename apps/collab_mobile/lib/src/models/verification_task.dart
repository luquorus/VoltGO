/// Verification Task Model
class VerificationTask {
  final String id;
  final String stationId;
  final String stationName;
  final String? changeRequestId;
  final int priority;
  final DateTime? slaDueAt;
  final String? assignedTo;
  final String? assignedToEmail;
  final VerificationTaskStatus status;
  final DateTime createdAt;
  final Checkin? checkin;
  final Review? review;

  VerificationTask({
    required this.id,
    required this.stationId,
    required this.stationName,
    this.changeRequestId,
    required this.priority,
    this.slaDueAt,
    this.assignedTo,
    this.assignedToEmail,
    required this.status,
    required this.createdAt,
    this.checkin,
    this.review,
  });

  factory VerificationTask.fromJson(Map<String, dynamic> json) {
    return VerificationTask(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      changeRequestId: json['changeRequestId'] as String?,
      priority: json['priority'] as int,
      slaDueAt: json['slaDueAt'] != null
          ? DateTime.parse(json['slaDueAt'] as String)
          : null,
      assignedTo: json['assignedTo'] as String?,
      assignedToEmail: json['assignedToEmail'] as String?,
      status: VerificationTaskStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      checkin: json['checkin'] != null
          ? Checkin.fromJson(json['checkin'] as Map<String, dynamic>)
          : null,
      review: json['review'] != null
          ? Review.fromJson(json['review'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationId': stationId,
      'stationName': stationName,
      if (changeRequestId != null) 'changeRequestId': changeRequestId,
      'priority': priority,
      if (slaDueAt != null) 'slaDueAt': slaDueAt!.toIso8601String(),
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (assignedToEmail != null) 'assignedToEmail': assignedToEmail,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      if (checkin != null) 'checkin': checkin!.toJson(),
      if (review != null) 'review': review!.toJson(),
    };
  }
}

/// Verification Task Status
enum VerificationTaskStatus {
  open,
  assigned,
  checkedIn,
  submitted,
  reviewed;

  static VerificationTaskStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'OPEN':
        return VerificationTaskStatus.open;
      case 'ASSIGNED':
        return VerificationTaskStatus.assigned;
      case 'CHECKED_IN':
        return VerificationTaskStatus.checkedIn;
      case 'SUBMITTED':
        return VerificationTaskStatus.submitted;
      case 'REVIEWED':
        return VerificationTaskStatus.reviewed;
      default:
        throw ArgumentError('Unknown status: $value');
    }
  }

  @override
  String toString() {
    switch (this) {
      case VerificationTaskStatus.open:
        return 'OPEN';
      case VerificationTaskStatus.assigned:
        return 'ASSIGNED';
      case VerificationTaskStatus.checkedIn:
        return 'CHECKED_IN';
      case VerificationTaskStatus.submitted:
        return 'SUBMITTED';
      case VerificationTaskStatus.reviewed:
        return 'REVIEWED';
    }
  }

  String get displayName {
    switch (this) {
      case VerificationTaskStatus.open:
        return 'Open';
      case VerificationTaskStatus.assigned:
        return 'Assigned';
      case VerificationTaskStatus.checkedIn:
        return 'Checked In';
      case VerificationTaskStatus.submitted:
        return 'Submitted';
      case VerificationTaskStatus.reviewed:
        return 'Reviewed';
    }
  }
}

/// Check-in information
class Checkin {
  final double lat;
  final double lng;
  final DateTime checkedInAt;
  final int? distanceM;
  final String? deviceNote;

  Checkin({
    required this.lat,
    required this.lng,
    required this.checkedInAt,
    this.distanceM,
    this.deviceNote,
  });

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      checkedInAt: DateTime.parse(json['checkedInAt'] as String),
      distanceM: json['distanceM'] as int?,
      deviceNote: json['deviceNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'checkedInAt': checkedInAt.toIso8601String(),
      if (distanceM != null) 'distanceM': distanceM,
      if (deviceNote != null) 'deviceNote': deviceNote,
    };
  }
}

/// Review information
class Review {
  final String result;
  final String? adminNote;
  final DateTime reviewedAt;
  final String reviewedBy;

  Review({
    required this.result,
    this.adminNote,
    required this.reviewedAt,
    required this.reviewedBy,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      result: json['result'] as String,
      adminNote: json['adminNote'] as String?,
      reviewedAt: DateTime.parse(json['reviewedAt'] as String),
      reviewedBy: json['reviewedBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result,
      if (adminNote != null) 'adminNote': adminNote,
      'reviewedAt': reviewedAt.toIso8601String(),
      'reviewedBy': reviewedBy,
    };
  }
}

/// Check-in request DTO
class CheckinRequest {
  final double lat;
  final double lng;
  final String? deviceNote;

  CheckinRequest({
    required this.lat,
    required this.lng,
    this.deviceNote,
  });

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      if (deviceNote != null) 'deviceNote': deviceNote,
    };
  }
}

