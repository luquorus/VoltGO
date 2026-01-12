/// Verification Task Model for Collaborator Web
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
  final CheckinInfo? checkin;
  final List<Evidence> evidences;
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
    this.evidences = const [],
    this.review,
  });

  factory VerificationTask.fromJson(Map<String, dynamic> json) {
    return VerificationTask(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      changeRequestId: json['changeRequestId'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      slaDueAt: json['slaDueAt'] != null
          ? DateTime.parse(json['slaDueAt'] as String)
          : null,
      assignedTo: json['assignedTo'] as String?,
      assignedToEmail: json['assignedToEmail'] as String?,
      status: VerificationTaskStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      checkin: json['checkin'] != null
          ? CheckinInfo.fromJson(json['checkin'] as Map<String, dynamic>)
          : null,
      evidences: json['evidences'] != null
          ? (json['evidences'] as List)
              .map((e) => Evidence.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
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
      'evidences': evidences.map((e) => e.toJson()).toList(),
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
class CheckinInfo {
  final double lat;
  final double lng;
  final DateTime checkedInAt;
  final int? distanceM;
  final String? deviceNote;

  CheckinInfo({
    required this.lat,
    required this.lng,
    required this.checkedInAt,
    this.distanceM,
    this.deviceNote,
  });

  factory CheckinInfo.fromJson(Map<String, dynamic> json) {
    return CheckinInfo(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.parse(json['checkedInAt'] as String)
          : DateTime.now(),
      distanceM: (json['distanceM'] as num?)?.toInt(),
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

/// Evidence information
class Evidence {
  final String id;
  final String photoObjectKey;
  final String? note;
  final DateTime submittedAt;
  final String submittedBy;

  Evidence({
    required this.id,
    required this.photoObjectKey,
    this.note,
    required this.submittedAt,
    required this.submittedBy,
  });

  factory Evidence.fromJson(Map<String, dynamic> json) {
    return Evidence(
      id: json['id'] as String,
      photoObjectKey: json['photoObjectKey'] as String,
      note: json['note'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      submittedBy: json['submittedBy'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photoObjectKey': photoObjectKey,
      if (note != null) 'note': note,
      'submittedAt': submittedAt.toIso8601String(),
      'submittedBy': submittedBy,
    };
  }
}

/// Review information
class Review {
  final String result; // PASS or FAIL
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

  bool get isPass => result == 'PASS';
  bool get isFail => result == 'FAIL';
}

/// Paginated response model
class PagedResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PagedResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PagedResponse<T>(
      content: json['content'] != null
          ? (json['content'] as List)
              .map((item) => fromJsonT(item as Map<String, dynamic>))
              .toList()
          : [],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }
}

