/// Admin Verification Task Model
/// 
/// Represents a verification task with all admin-specific fields
class AdminVerificationTask {
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

  AdminVerificationTask({
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

  factory AdminVerificationTask.fromJson(Map<String, dynamic> json) {
    return AdminVerificationTask(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String? ?? 'Unknown Station',
      changeRequestId: json['changeRequestId'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 3,
      slaDueAt: json['slaDueAt'] != null
          ? DateTime.parse(json['slaDueAt'] as String)
          : null,
      assignedTo: json['assignedTo'] as String?,
      assignedToEmail: json['assignedToEmail'] as String?,
      status: VerificationTaskStatus.fromString(json['status'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      checkin: json['checkin'] != null
          ? CheckinInfo.fromJson(json['checkin'] as Map<String, dynamic>)
          : null,
      evidences: (json['evidences'] as List<dynamic>?)
              ?.map((e) => Evidence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      review: json['review'] != null
          ? Review.fromJson(json['review'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get canAssign => status == VerificationTaskStatus.open;
  bool get canReview => status == VerificationTaskStatus.submitted;
}

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
        return VerificationTaskStatus.open;
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
}

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
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : DateTime.now(),
      submittedBy: json['submittedBy'] as String? ?? 'Unknown',
    );
  }
}

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
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'] as String)
          : DateTime.now(),
      reviewedBy: json['reviewedBy'] as String? ?? 'Unknown',
    );
  }

  bool get isPass => result == 'PASS';
  bool get isFail => result == 'FAIL';
}

/// Paginated response for verification tasks
class PagedVerificationTasks {
  final List<AdminVerificationTask> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  PagedVerificationTasks({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory PagedVerificationTasks.fromJson(Map<String, dynamic> json) {
    return PagedVerificationTasks(
      content: (json['content'] as List<dynamic>?)
              ?.map((e) => AdminVerificationTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }
}

